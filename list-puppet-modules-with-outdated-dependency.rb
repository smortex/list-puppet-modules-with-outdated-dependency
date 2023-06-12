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

unless ARGV[0] =~ %r{\A[[:alnum:]]+/[[:alnum:]]+\z}
  error(%(dependency-name must be "owner/module", got "#{ARGV[0]}"))
  exit 1
end

required_module_name = ARGV[0]
required_module_version = Gem::Version.new(ARGV[1])

query = "/v3/modules?#{{ exclude_fields: 'releases' }.merge($options).reject { |k| k == :verbose }.map { |k, v| "#{k}=#{v}" }.join('&')}"

while query
  info "GET #{query}"

  json = JSON.parse(URI.parse("#{base_uri}#{query}").open.read)

  json['results'].each do |result|
    name = result.dig('current_release', 'slug')
    version_requirement = result.dig('current_release', 'metadata', 'dependencies').select { |dependency| dependency['name'] == required_module_name }.dig(0, 'version_requirement')

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

    unless required_module_version >= Gem::Version.new(m[:lower]) && required_module_version < Gem::Version.new(m[:upper])
      summary[:outdated] += 1
      warn "#{name} (#{version_requirement}) needs updating"
      next
    end

    summary[:ok] += 1
    info "#{name} (#{version_requirement}) is fine"
  end

  query = json['pagination']['next']
end

summary[:total] = summary[:ok] + summary[:outdated] + summary[:malformed]

puts "#{summary[:total]} modules checked: #{summary[:ok]} ok; #{summary[:outdated]} outdated; #{summary[:malformed]} malformed"
