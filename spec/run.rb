#!/usr/bin/env ruby
require 'bundler'
require 'bundler/setup'

require 'chef_zero/server'
require 'rspec/core'

require 'pedant'
require 'pedant/opensource'

server = ChefZero::Server.new(port: 8889)
server.start_background

Pedant.config.suite = 'api'
Pedant.config[:config_file] = 'spec/support/pedant.rb'
Pedant.setup([
  '--skip-validation',
  '--skip-authentication',
  '--skip-authorization'
])

result = RSpec::Core::Runner.run(Pedant.config.rspec_args)

server.stop
exit(result)
