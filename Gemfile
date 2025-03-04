source "https://rubygems.org"

gemspec

# gem 'rest-client', :git => 'https://github.com/chef/rest-client.git'

group :pedant do
  gem "oc-chef-pedant", git: "https://github.com/chef/chef-server.git", branch: "main"
end

gem "ffi", ">= 1.15.5", "< 1.17.0"

group :development, :test do
  gem "chefstyle"
  gem "rake"
  gem "rspec", "~> 3.0"
end

if ENV["GEMFILE_MOD"]
  puts "GEMFILE_MOD: #{ENV["GEMFILE_MOD"]}"
  instance_eval(ENV["GEMFILE_MOD"])
else
  gem "chef", "~> 18.6"
  gem "ohai", "~> 18.0"
end

group :debug do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
end
