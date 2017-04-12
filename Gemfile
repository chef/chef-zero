source "https://rubygems.org"
gemspec

# gem 'rest-client', :git => 'https://github.com/chef/rest-client.git'

group :pedant do
  gem "oc-chef-pedant", :git => "https://github.com/chef/chef-server.git"
end

group :changelog do
  gem "github_changelog_generator", :git => "https://github.com/chef/github-changelog-generator.git"
end

group :development, :test do
  gem "chefstyle", "= 0.3.1"
end

gem "chef"

if ENV["GEMFILE_MOD"]
  puts "GEMFILE_MOD: #{ENV['GEMFILE_MOD']}"
  instance_eval(ENV["GEMFILE_MOD"])
end
