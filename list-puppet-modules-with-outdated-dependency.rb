#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open-uri'
require 'optparse'

base_uri = 'https://forgeapi.puppet.com'

$options = {
  verbose: false
}

summary = {
  outdated: 0,
  malformed: 0,
  ok: 0,
}

def info(msg)
  return unless $options[:verbose]

  puts "[-] #{msg}"
end

def warn(msg)
  $stderr.puts("[+] #{msg}")
end

def error(msg)
  $stderr.puts("[!] #{msg}")
end

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options] dependency-name dependency-version"

  opts.separator("\nGeneral options")
  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

  opts.separator("\nFiltering options")
  opts.on('-o', '--owner=OWNER', 'Only consider modules owned by OWNER') do |s|
    $options[:owner] = s
  end
  opts.on('-q', '--query=QUERY', 'Only consider modules matching QUERY') do |s|
    $options[:query] = s
  end
end.parse!

if ARGV.count != 2
  error("#{$PROGRAM_NAME} need exactly 2 parameters")
  exit 1
end

if ARGV[0] == 'puppet'
  requirement_path = %w[current_release metadata requirements]
  requirement = /\Apuppet\z/
else
  unless (m = ARGV[0].match(%r{\A(?<owner>[[:alnum:]]+)[/-](?<name>[[:alnum:]]+)\z}))
    error(%(dependency-name must be "owner/module", got "#{ARGV[0]}"))
    exit 1
  end

  requirement_path = %w[current_release metadata dependencies]

  required_module_owner = m[:owner]
  required_module_name = m[:name]
  requirement = %r{\A#{required_module_owner}[/-]#{required_module_name}\z}
end
requirement_version = Gem::Version.new(ARGV[1])

query = "/v3/modules?#{{ exclude_fields: 'releases', hide_deprecated: 'yes' }.merge($options).reject { |k| k == :verbose }.map { |k, v| "#{k}=#{v}" }.join('&')}"

while query
  info "GET #{query}"

  json = JSON.parse(URI.parse("#{base_uri}#{query}").open.read)

  json['results'].each do |result|
    name = result.dig('current_release', 'slug')
    version_requirement = result.dig(*requirement_path).select { |dependency| dependency['name'].match(requirement) }.dig(0, 'version_requirement')

    unless version_requirement
      summary[:ok] += 1
      info("#{name}: no dependency on #{required_module_name}")
      next
    end

    m = version_requirement.match(/\A>=[[:blank:]]*(?<lower>.*)[[:blank:]]+<[[:blank:]]*(?<upper>.*)\z/)

    unless m
      summary[:malformed] += 1
      error("#{name} (#{version_requirement}): ignored (malformed version requirement)")
      next
    end

    unless requirement_version >= Gem::Version.new(m[:lower]) && requirement_version < Gem::Version.new(m[:upper])
      summary[:outdated] += 1
      warn "#{name} (#{version_requirement}) needs updating"
      next
    end

    summary[:ok] += 1
    info "#{name} (#{version_requirement}) is fine"
  rescue ArgumentError
    error("#{name} (#{version_requirement}): ignored (ArgumentError)")
  end

  query = json['pagination']['next']
end

summary[:total] = summary[:ok] + summary[:outdated] + summary[:malformed]

puts "#{summary[:total]} modules checked: #{summary[:ok]} ok; #{summary[:outdated]} outdated; #{summary[:malformed]} malformed"
