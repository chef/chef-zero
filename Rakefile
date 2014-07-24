require 'bundler'
require 'bundler/gem_tasks'

require 'chef_zero/version'

task :default => :pedant

task :spec do
  system('rspec spec/*_spec.rb')
end

task :pedant do
  require File.expand_path('spec/run_pedant')
end

task :oc_pedant do
  require File.expand_path('spec/run_oc_pedant')
end

task :chef_spec do
  gem_path = Bundler.environment.specs['chef'].first.full_gem_path
  system("cd #{gem_path} && rspec spec/integration")
end

task :berkshelf_spec do
  gem_path = Bundler.environment.specs['berkshelf'].first.full_gem_path
  system("cd #{gem_path} && thor spec:ci")
end
