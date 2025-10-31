source "https://rubygems.org"

gemspec

gem "rest-client", :git => "https://github.com/chef/rest-client.git", branch: "jfm/ucrt_update1"

group :pedant do
  gem "oc-chef-pedant", git: "https://github.com/chef/chef-server.git", branch: "main"
end

gem "ffi", ">= 1.15.5"

group :development, :test do
  gem "rake"
  gem "rspec", "~> 3.0"
  gem "yard"
  gem "webrick"
end

group :style do
  gem "cookstyle", "~> 8.2"
end

if ENV["GEMFILE_MOD"]
  puts "GEMFILE_MOD: #{ENV["GEMFILE_MOD"]}"
  instance_eval(ENV["GEMFILE_MOD"])
else
  gem "chef", "~> 18.7"
  gem "ohai", "~> 18.1"
end

group :debug do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
end
