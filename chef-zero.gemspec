$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef_zero/version'

Gem::Specification.new do |s|
  s.name = 'chef-zero'
  s.version = ChefZero::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = 'Self-contained, easy-setup, fast-start in-memory Chef server for testing and solo setup purposes'
  s.description = s.summary
  s.author = 'John Keiser'
  s.email = 'jkeiser@opscode.com'
  s.homepage = 'http://www.opscode.com'
  s.license = 'Apache 2.0'

  s.add_dependency 'mixlib-log',    '~> 1.3'
  s.add_dependency 'hashie',        '~> 2.0'
  s.add_dependency 'uuidtools', '~> 2.1'
  s.add_dependency 'ffi-yajl', '~> 1.1'
  s.add_dependency 'rack'

  s.add_development_dependency 'rake'

  # pedant incompatible with RSpec 3.2 as of pedant version 1.0.42
  s.add_development_dependency 'rspec', '~> 3.1.0'

  s.bindir       = 'bin'
  s.executables  = ['chef-zero']
  s.require_path = 'lib'
  s.files = %w(LICENSE README.md Rakefile) + Dir.glob('{lib,spec}/**/*')
end
