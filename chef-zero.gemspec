$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef_zero/version'
require 'rbconfig'

Gem::Specification.new do |s|
  s.name = 'chef-zero'
  s.version = ChefZero::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = 'Self-contained, easy-setup, fast-start in-memory Chef server for testing and solo setup purposes'
  s.description = s.summary
  s.author = 'John Keiser'
  s.email = 'jkeiser@opscode.com'
  s.homepage = 'http://www.opscode.com'

  if ENV['SERVER'] == 'thin' || RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
    # Windows and/or explicit thin testing
    s.add_dependency 'thin', '~> 1.5'
  else
    # Everyone else
    s.add_dependency 'puma', '~> 2.0'
  end

  s.add_dependency 'mixlib-log',    '~> 1.3'
  s.add_dependency 'hashie',        '~> 2.0'
  s.add_dependency 'moneta',        '< 0.7.0' # For chef, see CHEF-3721

  s.add_development_dependency 'rake'

  s.bindir       = 'bin'
  s.executables  = ['chef-zero']
  s.require_path = 'lib'
  s.files = %w(LICENSE README.md Rakefile) + Dir.glob('{lib,spec}/**/*')
end

