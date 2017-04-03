$:.unshift(File.dirname(__FILE__) + "/lib")
require "chef_zero/version"

Gem::Specification.new do |s|
  s.name = "chef-zero"
  s.version = ChefZero::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = "Self-contained, easy-setup, fast-start in-memory Chef server for testing and solo setup purposes"
  s.description = s.summary
  s.author = "John Keiser"
  s.email = "jkeiser@chef.io"
  s.homepage = "http://www.chef.io"
  s.license = "Apache 2.0"

  s.required_ruby_version = ">= 2.3.1"

  s.add_dependency "mixlib-log", "~> 1.3"
  s.add_dependency "hashie", ">= 2.0", "< 4.0"
  s.add_dependency "uuidtools", "~> 2.1"
  s.add_dependency "ffi-yajl", "~> 2.2"
  s.add_dependency "rack", "~> 2.0"

  s.add_development_dependency "pry"
  s.add_development_dependency "pry-byebug"
  s.add_development_dependency "pry-stack_explorer"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"

  s.bindir       = "bin"
  s.executables  = ["chef-zero"]
  s.require_path = "lib"
  s.files = %w{LICENSE README.md Gemfile Rakefile} + Dir.glob("*.gemspec") +
    Dir.glob("{lib,spec}/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
end
