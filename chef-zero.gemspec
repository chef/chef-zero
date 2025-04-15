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
  s.add_dependency "activesupport", "~> 7.0", "< 7.1"
  s.add_dependency "mixlib-log", ">= 2.0", "< 4.0"
  s.add_dependency "hashie", ">= 2.0", "< 6.0"
  s.add_dependency "uuidtools", "~> 2.1"
  s.add_dependency "ffi-yajl", "~> 2.2"
  s.add_dependency "rack", "~> 3.1", ">= 3.1.10"
  s.add_dependency "rackup", "~> 2.2", ">= 2.2.1"
  s.add_dependency "webrick"

  s.bindir       = "bin"
  s.executables  = ["chef-zero"]
  s.require_path = "lib"
  s.files = %w{LICENSE Gemfile Rakefile} + Dir.glob("*.gemspec") +
    Dir.glob("{lib,spec}/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
end
