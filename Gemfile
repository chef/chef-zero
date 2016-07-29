source "https://rubygems.org"
gemspec

# gem 'rest-client', :github => 'chef/rest-client'

gem "oc-chef-pedant", :github => "chef/chef-server"

group :changelog do
  gem "github_changelog_generator"
end

group :development, :test do
  gem "chefstyle", "= 0.3.1"
end

# bundler resolve failure on "rspec_junit_formatter"
# gem 'chef-pedant', :github => 'opscode/chef-pedant', :ref => "server-cli-option"

# gem 'chef', :github => 'chef/chef', :branch => 'jk/policies-acls'

if ENV["GEMFILE_MOD"]
  puts "GEMFILE_MOD: #{ENV['GEMFILE_MOD']}"
  instance_eval(ENV["GEMFILE_MOD"])
end
