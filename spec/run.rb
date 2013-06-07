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
  result = 0
end

server.stop
exit(result)
