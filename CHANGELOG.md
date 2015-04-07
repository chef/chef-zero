Chef Zero CHANGELOG
===================

# 4.2.1

* [PR#125](https://github.com/chef/chef-zero/pull/125): Don't polute
  global chef_server configs when running RSpec

# 4.2.0

* [PR#124](https://github.com/chef/chef-zero/pull/124): Bump ffi-yajl
  dependency
* [PR#119](https://github.com/chef/chef-zero/pull/119): Add
  :organization and :data_scope options to RSpec support method
  `with_chef_server`

# 4.1.0

* [PR#121](https://github.com/chef/chef-zero/pull/121): Add Socketless
  mode.
* [**Phil Dibowitz**](https://github.com/jaymzh):
  Added support for /version

# 4.0 (2/11/2014)

- Add policyfile endpoints
- Remove Ruby 1.8 and 1.9 support

# 3.2 (9/26/2014)

* removed 'json' gem dependency, replaced it with 'ffi-yajl'

# 3.1.3 (9/3/2014)

* fixes for running Chef local mode in multi-org mode

# 3.1.2 (8/29/2014)

* add default to rspec for cookbooks
* add /organizations/NAME/organization/_acl as an alias for /organizations/NAME/organizations/_acl

# 3.1.1 (8/28/2014)

* fix minor bug with unknown container acls

# 3.1 (8/28/2014)

* New rspec data directives: organization, acl, group, container
* Fix organizations POST to honor full_name
* Fixes for enterprise rspec data loading
* Fix invites not removing the invite when user is forcibly added to an org

# 3.0 (7/22/2014)

* Enterprise Chef support (organizations, ACLs, groups, much more)
* SSL support (@sawanoboly)

# 2.2 (6/18/2014)

* allow port ranges to be passed in as enumerables, which will be tried in sequence until one works: `ChefZero::Server.new(:port => 80.upto(100))`

# 2.1.5 (6/2/2014)

* fix issue with :single_org => <value> not being honored

# 2.1.4 (5/27/2014)

* fix issue with global Thread.exit_on_exception being set

# 2.1.3 (5/27/2014)

* rspec: default port to 8900 to not conflict with normal default port
* rspec: when chef_zero_opts is set, check if current server has those options before continuing

# 2.1.2 (5/27/2014)

* fix build_uri (and thus cookbook downloads)

# 2.1.1 (5/26/2014)

* flip defaults off in V1ToV2Adapater, allowing most chef tests to pass against 2.1.1

# 2.1 (5/26/2014)

* **Multi-tenancy!**  If you set :single_org => nil when starting the server, you will gain /organizations/* at the beginning of all URLs.  Internally, all endpoints are rooted at /organizations/ORG anyway, there is just a translation that goes on to add /organizations/single_org to the URL when someone hits chef-zero.
* Fixes to support chef-zero local mode passing pedant

# 2.0.2 (1/20/2014)

* Fix a series of typos in the README
* Read JSON, not a file path in `from_json`
* Fix IPV6 support
* Remove moneta as a dependency

# 2.0.1 (1/3/2014)

* Make playground items more semantic
* Fix an issue where an incorrect number of parameters was passed in `environments/NAME/nodes` endpoint
* Fix an issue where the `data_store` was not yet initialized in the server

# 2.0.0 (12/17/2013)

* Remove Puma (and `--socket` option)
* Use a cleaner threading approach
* Implement a better `running?` check

# 1.7.3

* (Backport) Read JSON, not a file path in `from_json`

# 1.6.3

* (Backport) Read JSON, not a file path in `from_json`

# 1.5.5

* Fix issue with - in term (name:a-b)

# 1.5.4

* Fix issue where run_lists in format cookbook::recipe@version do not depsolve

# 1.5.3

* Add Server: chef-zero header to response

# 1.5.2

* Fix a couple of search query issues (make parentheses and NOT term:value work)

# 1.5.1

* Add Unix domain socket support (e.g. chef-zero --socket /tmp/chef-zero.sock) (stevendanna)

# 1.5

* Add -d option for daemon mode (sethvargo)
* Fix bug with cookbook metadata.rb files that rely on __FILE__

# 1.4

* Run with downgraded Puma 1.6 in order to work on Windows (2.x doesn't yet)

# 1.3

* Fix bug with search when JSON contains the same key in different places

# 1.2.1

* Fix search when JSON contains integers

# 1.2

* Allow rspec users to specify cookbook NAME, VERSION, { :frozen => true }
* Documentation fix

# 1.1.3

* Return better defaults for cookbooks
* Support /cookbook_versions?cookbook_versions=... query parameter
* Fix server crash when cookbook has multiple identical checksums

# 1.1.2

* Allow rspec users to specify the same data twice (overwrites)

# 1.1.1

* Fix broken rspec functionality (jkeiser, reset)

# 1.1

* Create plugin system to allow other storage besides memory

# 1.0.1

* Fix depsolver crash with frozen version strings (sethvargo)

# 1.0

* Increased testing of server

# 0.9.13

* Remove extra require of 'thin' so rspec users don't get broke

# 0.9.12

* Switch from thin to puma (sethvargo)

# 0.9.11

* Support full cookbook metadata.rb syntax, including "depends"

# 0.9.10

* Add -d flag to print debug output (sethvargo)

# 0.9.9

* Remove chef as a dependency so we can run on jruby (reset)
* Server assumes json is acceptable if Accept header is not sent (stevendanna)

# 0.9.8

* Support runlists with a::b in them in depsolver

# 0.9.7

* Return file URLs and other important things in depsolver response

# 0.9.6

* Make 404 a JSON response

# 0.9.5

* Fix crash in 405 error response generator
* Add ability to verify request/response pairs from rspec api

# 0.9.4

* Ruby 1.8.7 support

# 0.9.3

* rspec fixes:
  - Faster (0 retries)
  - Work with more than one test
  - Allow tags on when_the_chef_server
* make 500 response return actual exception info

# 0.9.2

* Speed increase for rspec (only start server once)
* Support CTRL+C when running rspec chef-zero tests

# 0.9.1

* Switch from webrick -> thin
* Bugfixes

# 0.9

* Initial code-complete release with working server
