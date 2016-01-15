#!/usr/bin/env ruby
require 'bundler'
require 'bundler/setup'

require 'chef_zero/server'
require 'rspec/core'

def start_cheffs_server(chef_repo_path)
  require 'chef/version'
  require 'chef/config'
  require 'chef/chef_fs/config'
  require 'chef/chef_fs/chef_fs_data_store'
  require 'chef_zero/server'

  Dir.mkdir(chef_repo_path) if !File.exists?(chef_repo_path)

  # 11.6 and below had a bug where it couldn't create the repo children automatically
  if Chef::VERSION.to_f < 11.8
    %w(clients cookbooks data_bags environments nodes roles users).each do |child|
      Dir.mkdir("#{chef_repo_path}/#{child}") if !File.exists?("#{chef_repo_path}/#{child}")
    end
  end

  # Start the new server
  Chef::Config.repo_mode = 'hosted_everything'
  Chef::Config.chef_repo_path = chef_repo_path
  Chef::Config.versioned_cookbooks = true
  chef_fs_config = Chef::ChefFS::Config.new

  data_store = Chef::ChefFS::ChefFSDataStore.new(chef_fs_config.local_fs, chef_fs_config.chef_config)
  data_store = ChefZero::DataStore::V1ToV2Adapter.new(data_store, 'pedant-testorg')
  data_store = ChefZero::DataStore::DefaultFacade.new(data_store, 'pedant-testorg', false)
  data_store.create(%w(organizations pedant-testorg users), 'pivotal', '{}')
  data_store.set(%w(organizations pedant-testorg groups admins), '{ "users": [ "pivotal" ] }')
  data_store.set(%w(organizations pedant-testorg groups users), '{ "users": [ "pivotal" ] }')

  server = ChefZero::Server.new(
    port: 8889,
    data_store: data_store,
    single_org: false,
    #log_level: :debug
  )
  server.start_background
  server
end

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

  elsif ENV['CHEF_FS']
    require 'tmpdir'
    tmpdir = Dir.mktmpdir
    server = start_cheffs_server(tmpdir)

  else
    server = ChefZero::Server.new(:port => 8889, :single_org => false)#, :log_level => :debug)
    server.start_background
  end

  require 'rspec/core'
  require 'pedant'
  require 'pedant/organization'

  # Pedant::Config.rerun = true

  Pedant.config.suite = 'api'

  Pedant.config[:config_file] = 'spec/support/oc_pedant.rb'

  # Because ChefFS can only ever have one user (pivotal), we can't do most of the
  # tests that involve multiple
  chef_fs_skips = if ENV['CHEF_FS']
    [ '--skip-association',
      '--skip-users',
      '--skip-organizations',
      '--skip-multiuser',

      # chef-zero has some non-removable quirks, such as the fact that files
      # with 255-character names cannot be stored in local mode. This is
      # reserved only for quirks that are *irrevocable* and by design; and
      # should barely be used at all.
      '--skip-chef-zero-quirks',
    ]
  else
    []
  end

  # "the goal is that only authorization, authentication and validation tests are turned off" - @jkeiser
  Pedant.setup([
    '--skip-knife',
    '--skip-keys',
    '--skip-controls',
    '--skip-acl',
    '--skip-headers',

    # Chef Zero does not intend to support validation the way erchef does.
    '--skip-validation',

    # Chef Zero does not intend to support authentication the way erchef does.
    '--skip-authentication',

    # Chef Zero does not intend to support authorization the way erchef does.
    '--skip-authorization',

    # Omnibus tests depend on erchef features that are specific to erchef and
    # bundled in the omnibus package. Currently the only test in this category
    # is for the search reindexing script.
    '--skip-omnibus',

    # USAGs (user-specific association groups) are Authz groups that contain
    # only one user and represent that user's association with an org. Though
    # there are good reasons for them, they don't work well in practice and
    # only the manage console really uses them. Since Chef Zero + Manage is a
    # quite unusual configuration, we're ignoring them.
    '--skip-usags',

    # Chef 12 features not yet 100% supported by Chef Zero
    '--skip-containers',
    '--skip-api-v1',

    # The universe endpoint is unlikely to ever make sense for Chef Zero
    '--skip-universe'
  ] + chef_fs_skips)

  fail_fast = []
  # fail_fast = ["--fail-fast"]

  result = RSpec::Core::Runner.run(Pedant.config.rspec_args + fail_fast)

  server.stop if server.running?
ensure
  FileUtils.remove_entry_secure(tmpdir) if tmpdir
end

exit(result)
