$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef_zero/version'

Gem::Specification.new do |s|
  s.name = "chef-zero"
  s.version = ChefZero::VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "LICENSE"]
  s.summary = "Self-contained, easy-setup, fast-start in-memory Chef server for testing and solo setup purposes"
  s.description = s.summary
  s.author = "John Keiser"
  s.email = "jkeiser@opscode.com"
  s.homepage = "http://www.opscode.com"

  s.add_dependency 'chef' # For version, version constraint and deep merge
  s.add_dependency 'thin' # webrick DOES NOT FREAKING WORK
  s.add_dependency 'mixlib-log', '>= 1.3.0'
  s.add_dependency 'solve', '>= 0.4.3'

  s.bindir       = "bin"
  s.executables  = %w( chef-zero )
  s.require_path = 'lib'
  s.files = %w(LICENSE README.rdoc Rakefile) + Dir.glob("{lib,spec}/**/*")
end

