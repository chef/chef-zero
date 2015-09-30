require 'bundler'
require 'bundler/gem_tasks'

require 'chef_zero/version'

task :default => :pedant

desc "run specs"
task :spec do
  system('rspec spec/*_spec.rb')
end

desc "run oc pedant"
task :pedant do
  require File.expand_path('spec/run_oc_pedant')
end

desc "run oc pedant"
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

require 'github_changelog_generator/task'

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.token = ENV['GITHUB_CHANGELOG_TOKEN']
  # config.future_release = ChefZero::VERSION
  config.enhancement_labels = "enhancement,Enhancement,New Feature".split(',')
  config.bug_labels = "bug,Bug,Improvement,Upstream Bug".split(',')
  config.exclude_labels = "duplicate,question,invalid,wontfix,no_changelog".split(',')
end
