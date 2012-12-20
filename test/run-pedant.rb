#!/usr/bin/env ruby

require 'rubygems'
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))
require 'chef_zero/server'

thread = Thread.new do
  server = ChefZero::Server.new(:Port => 8889)
  server.start
end

system('git clone git://github.com/opscode/chef-pedant.git')
#system('cd chef-pedant && git pull')
system('cd chef-pedant && git reset --hard 458a3eed89915ff54913040f0001fd2ccd75511b')
system('cd chef-pedant && bundle install')
result = system('cd chef-pedant && bin/chef-pedant -c ../chef-zero-pedant-config.rb --skip-validation --skip-authentication --skip-authorization')
thread.kill
exit(result)
