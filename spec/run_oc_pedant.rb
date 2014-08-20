#!/usr/bin/env ruby
require 'bundler'
require 'bundler/setup'

require 'chef_zero/server'
require 'rspec/core'

tmpdir = nil

begin
  if ENV['FILE_STORE']
    require 'tmpdir'
    require 'chef_zero/data_store/raw_file_store'
    tmpdir = Dir.mktmpdir
    data_store = ChefZero::DataStore::RawFileStore.new(tmpdir, true)
    data_store = ChefZero::DataStore::DefaultFacade.new(data_store, false, false)
    server = ChefZero::Server.new(:port => 8889, :single_org => false, :data_store => data_store)
    server.start_background

  else
    server = ChefZero::Server.new(:port => 8889, :single_org => false)#, :log_level => :debug)
    server.start_background
  end

  require 'rspec/core'
  require 'pedant'
  require 'pedant/opensource/platform'
  require 'pedant/multitenant'
  require 'pedant/organization'

  #Pedant::Config.rerun = true

  Pedant.config.suite = 'api'
  Pedant.config[:config_file] = 'spec/support/oc_pedant.rb'
  Pedant.setup([
    '--skip-knife',
    '--skip-validation',
    '--skip-authentication',
    '--skip-authorization',
    '--skip-omnibus',
    '--skip-usags',
    '--skip-internal_orgs',
    '--skip-rename_org'
  ])

  result = RSpec::Core::Runner.run(Pedant.config.rspec_args)

  server.stop if server.running?
ensure
  FileUtils.remove_entry_secure(tmpdir) if tmpdir
end

exit(result)
