$:.unshift(__dir__ + "/lib")
require "chef_zero/version"

Gem::Specification.new do |s|
  s.name = "chef-zero"
  s.version = ChefZero::VERSION
  s.summary = "Self-contained, easy-setup, fast-start in-memory Chef server for testing and solo setup purposes"
  s.description = s.summary
  s.author = "Chef Software, Inc."
  s.email = "oss@chef.io"
  s.homepage = "https://github.com/chef/chef-zero"
  s.license = "Apache-2.0"

  s.required_ruby_version = ">= 3.0"

  # Note: 7.1.0 does not defaults its cache_format_version to 7.1 but 6.1 instead which gives deprecation warnings
  # Remove the version constraint when we can upgrade to 7.1.1 post stable release of Activesupport 7.1
  # Similar issue with 7.0 existed: https://github.com/rails/rails/pull/45293
  s.add_dependency "activesupport", "~> 7.1.5"
  s.add_dependency "mixlib-log", ">= 2.0", "< 4.0"
  s.add_dependency "hashie", ">= 2.0", "< 6.0"
  s.add_dependency "uuidtools", "~> 2.1"
  s.add_dependency "ffi-yajl", ">= 2.2", "< 4.0"
  s.add_dependency "rack", "~> 3.1", ">= 3.1.16"
  s.add_dependency "rackup", "~> 2.2", ">= 2.2.1"
  s.add_dependency "unf_ext", "~> 0.0.8"
  s.add_dependency "webrick"

  # We are running into some challenging things with activesupport and fiddle. 
  # Chef-18 requires Ruby 3.1 and Chef-19 requires Ruby 3.4. They have incompatible dependencies on activesupport and fiddle
  # Activesupport 7.1.3.2 also has a CVE in it which requires an upgrade to 7.1.5.2. Activesupport 7.1.5 requires fiddle = 1.1.0, but Chef-19 requires fiddle >= 1.1.6.
  # Also, fiddle is a built-in gem for Ruby 3.1 but is broken out into a separate gem starting in Ruby 3.2.
  if Gem::Version.new(RUBY_VERSION) <= Gem::Version.new("3.1.7")
    s.add_dependency "fiddle", "= 1.1.0"
  else
    s.add_dependency "fiddle", ">= 1.1.6"
  end

  s.bindir       = "bin"
  s.executables  = ["chef-zero"]
  s.require_path = "lib"
  s.files = %w{LICENSE Gemfile Rakefile} + Dir.glob("*.gemspec") +
    Dir.glob("{lib,spec}/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
end
