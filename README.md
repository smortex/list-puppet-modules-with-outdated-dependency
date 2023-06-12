# list-puppet-modules-with-outdated-dependency

Query the [Puppet Forge](https://forge.puppetlabs.com/) and report modules dependencies that need updating.

## Rationale

When a new major version of a "base" module is released, all modules that depend on it need to be updated announce that they support the new major release.  Organizations that handle many modules may want to have a convenient overview of the current state of their modules.

## Usage

```sh-session
$ ./list-puppet-modules-with-outdated-dependency.rb --help
Usage: ./list-puppet-modules-with-outdated-dependency.rb [options] dependency-name dependency-version

General options
-v, --[no-]verbose               Run verbosely

Filtering options
-o, --owner=OWNER                Only consider modules owned by OWNER
-q, --query=QUERY                Only consider modules matching QUERY
```

## Example

Report modules support for `puppetlabs/stdlib` version `9.0.0`, scoping to the `puppetlabs` organization and matching `postfix`.

```sh-session
$ ./list-puppet-modules-with-outdated-dependency.rb --owner puppetlabs --query apache puppetlabs/stdlib 9.0.0
[+] puppetlabs-apache-10.0.0 (>= 4.13.1 < 9.0.0) needs updating
[+] puppetlabs-concat-8.0.1 (>= 4.13.1 < 9.0.0) needs updating
[+] puppetlabs-passenger-0.4.1 (>= 3.2.0 < 5.0.0) needs updating
[+] puppetlabs-firewall-5.0.0 (>= 4.0.0 < 9.0.0) needs updating
[!] puppetlabs-corosync-0.7.0 (4.x): ignored (malformed version requirement)
[+] puppetlabs-mrepo-1.2.1 (>= 0.1.6 < 5.0.0) needs updating
25 modules checked: 19 ok; 5 outdated; 1 malformed
```
