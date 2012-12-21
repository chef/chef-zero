require 'bundler'
require 'rubygems'
require 'rubygems/package_task'
require 'rdoc/task'

Bundler::GemHelper.install_tasks

gem_spec = eval(File.read("chef-zero.gemspec"))

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "chef-zero #{gem_spec.version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task :test do
  sh "cd test && ruby run-pedant.rb"
end
