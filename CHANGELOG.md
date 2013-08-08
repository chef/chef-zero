# 1.5.5

- Fix issue with - in term (name:a-b)

# 1.5.4

- Fix issue where run_lists in format cookbook::recipe@version do not depsolve

# 1.5.3

- Add Server: chef-zero header to response

# 1.5.2

- Fix a couple of search query issues (make parentheses and NOT term:value work)

# 1.5.1

- Add Unix domain socket support (e.g. chef-zero --socket /tmp/chef-zero.sock) (stevendanna)

# 1.5

- Add -d option for daemon mode (sethvargo)
- Fix bug with cookbook metadata.rb files that rely on __FILE__

# 1.4

- Run with downgraded Puma 1.6 in order to work on Windows (2.x doesn't yet)

# 1.3

- Fix bug with search when JSON contains the same key in different places

# 1.2.1

- Fix search when JSON contains integers

# 1.2

- Allow rspec users to specify cookbook NAME, VERSION, { :frozen => true }
- Documentation fix

# 1.1.3

- Return better defaults for cookbooks
- Support /cookbook_versions?cookbook_versions=... query parameter
- Fix server crash when cookbook has multiple identical checksums

# 1.1.2

- Allow rspec users to specify the same data twice (overwrites)

# 1.1.1

- Fix broken rspec functionality (jkeiser, reset)

# 1.1

- Create plugin system to allow other storage besides memory

# 1.0.1

- Fix depsolver crash with frozen version strings (sethvargo)

# 1.0

- Increased testing of server

# 0.9.13

- Remove extra require of 'thin' so rspec users don't get broke

# 0.9.12

- Switch from thin to puma (sethvargo)

# 0.9.11

- Support full cookbook metadata.rb syntax, including "depends"

# 0.9.10

- Add -d flag to print debug output (sethvargo)

# 0.9.9

- Remove chef as a dependency so we can run on jruby (reset)
- Server assumes json is acceptable if Accept header is not sent (stevendanna)

# 0.9.8

- Support runlists with a::b in them in depsolver

# 0.9.7

- Return file URLs and other important things in depsolver response

# 0.9.6

- Make 404 a JSON response

# 0.9.5

- Fix crash in 405 error response generator
- Add ability to verify request/response pairs from rspec api

# 0.9.4

- Ruby 1.8.7 support

# 0.9.3

- rspec fixes:
  - Faster (0 retries)
  - Work with more than one test
  - Allow tags on when_the_chef_server
- make 500 response return actual exception info

# 0.9.2

- Speed increase for rspec (only start server once)
- Support CTRL+C when running rspec chef-zero tests

# 0.9.1

- Switch from webrick -> thin
- Bugfixes

# 0.9

- Initial code-complete release with working server
