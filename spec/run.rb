#!/usr/bin/env ruby
require 'bundler'
require 'bundler/setup'

require 'chef_zero/server'
require 'rspec/core'

server = ChefZero::Server.new(:port => 8889)
server.start_background

unless ENV['SKIP_PEDANT']
  require 'pedant'
  require 'pedant/opensource'

  Pedant.config.suite = 'api'
  Pedant.config[:config_file] = 'spec/support/pedant.rb'
  Pedant.setup([
    '--skip-validation',
    '--skip-authentication',
    '--skip-authorization'
  ])

  result = RSpec::Core::Runner.run(Pedant.config.rspec_args)
else
  require 'net/http'
  response = Net::HTTP.new('127.0.0.1', 8889).get("/environments", { 'Accept' => 'application/json'}).body
  if response =~ /_default/
    result = 0
  else
    puts "GET /environments returned #{response}.  Expected _default!"
    result = 1
  end
end

server.stop
exit(result)
