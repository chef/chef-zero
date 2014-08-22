require 'tempfile'
require 'chef_zero/server'
require 'chef_zero/rest_request'

module ChefZero
  module RSpec
    def self.server
      @server
    end
    def self.server=(value)
      @server = value
    end
    def self.client_key
      @client_key
    end
    def self.client_key=(value)
      @client_key = value
    end
    def self.request_log
      @request_log ||= []
    end
    def self.clear_request_log
      @request_log = []
    end

    def when_the_chef_server(description, *tags, &block)
      context "When the Chef server #{description}", *tags do
        before :each do

          default_opts = {:port => 8900, :signals => false, :log_requests => true}
          server_opts = if self.respond_to?(:chef_zero_opts)
            default_opts.merge(chef_zero_opts)
          else
            default_opts
          end

          if ChefZero::RSpec.server && server_opts != ChefZero::RSpec.server.options
            ChefZero::RSpec.server.stop
            ChefZero::RSpec.server = nil
          end

          unless ChefZero::RSpec.server
            # TODO: can this be logged easily?
            # pp :zero_opts => server_opts

            # Set up configuration so that clients will point to the server
            ChefZero::RSpec.server = ChefZero::Server.new(server_opts)
            ChefZero::RSpec.client_key = Tempfile.new(['chef_zero_client_key', '.pem'])
            ChefZero::RSpec.client_key.write(ChefZero::PRIVATE_KEY)
            ChefZero::RSpec.client_key.close
            # Start the server
            ChefZero::RSpec.server.start_background
            ChefZero::RSpec.server.on_response do |request, response|
              ChefZero::RSpec.request_log << [ request, response ]
            end
          else
            ChefZero::RSpec.server.clear_data
          end
          ChefZero::RSpec.clear_request_log

          if defined?(Chef::Config)
            @old_chef_server_url = Chef::Config.chef_server_url
            @old_node_name = Chef::Config.node_name
            @old_client_key = Chef::Config.client_key
            Chef::Config.chef_server_url = ChefZero::RSpec.server.url
            Chef::Config.node_name = 'admin'
            Chef::Config.client_key = ChefZero::RSpec.client_key.path
            Chef::Config.http_retry_count = 0
          end
        end

        if defined?(Chef::Config)
          after :each do
            Chef::Config.chef_server_url = @old_chef_server_url
            Chef::Config.node_name = @old_node_name
            Chef::Config.client_key = @old_client_key
          end
        end

        def self.organization(name, org = '{}')
          before(:each) do
            ChefZero::RSpec.server.data_store.set([ 'organizations', name, 'org' ], dejsonize(org), :create_dir, :create)
            @current_org = name
          end
        end

        def self.acl(path, acl)
          before(:each) do
            path = [ 'organizations', @current_org || 'chef' ] + path.split('/')
            ChefZero::RSpec.server.data_store.set(ChefData::AclPath.get_acl_data_path(path), acl)
          end
        end

        def self.group(name, group)
          before(:each) do
            path = [ 'organizations', @current_org || 'chef' ] + path.split('/')
            ChefZero::RSpec.server.data_store.set([ 'organizations', @current_org || 'chef', 'groups', name ], dejsonize(group), :create)
          end
        end

        def self.org_invite(username)
          before(:each) do
            ChefZero::RSpec.server.data_store.set([ 'organizations', @current_org || 'chef', 'users', username ], '{}', :create)
          end
        end

        def self.org_members(name, *members)
          before(:each) do
            members.each do |member|
              ChefZero::RSpec.server.set([ 'organizations', @current_org || 'chef', 'users', member], '{}')
            end
          end
        end

        def self.client(name, client)
          before(:each) { ChefZero::RSpec.server.load_data({ 'clients' => { name => client }}, @current_org) }
        end

        def self.cookbook(name, version, cookbook, options = {})
          before(:each) { ChefZero::RSpec.server.load_data({ 'cookbooks' => { "#{name}-#{version}" => cookbook.merge(options) }}, @current_org) }
        end

        def self.data_bag(name, data_bag)
          before(:each) { ChefZero::RSpec.server.load_data({ 'data' => { name => data_bag }}, @current_org) }
        end

        def self.environment(name, environment)
          before(:each) { ChefZero::RSpec.server.load_data({ 'environments' => { name => environment }}, @current_org) }
        end

        def self.node(name, node)
          before(:each) { ChefZero::RSpec.server.load_data({ 'nodes' => { name => node }}, @current_org) }
        end

        def self.role(name, role)
          before(:each) { ChefZero::RSpec.server.load_data({ 'roles' => { name => role }}, @current_org) }
        end

        def self.user(name, user)
          if ChefZero::RSpec.server.options[:osc_compat]
            before(:each) { ChefZero::RSpec.server.load_data({ 'users' => { name => user }}, @current_org) }
          else
            before(:each) { ChefZero::RSpec.server.set([ 'users', name ], dejsonize(user)) }
          end
        end

        def self.dejsonize(data)
          if data.is_a?(String)
            data
          else
            JSON.pretty_generate(value)
          end
        end

#        after :each do
#          if @@ChefZero::RSpec.server
#            @@ChefZero::RSpec.server.stop
#            @@ChefZero::RSpec.server = nil
#          end
#          if @@ChefZero::RSpec.client_key
#            @@ChefZero::RSpec.client_key.unlink
#            @@ChefZero::RSpec.client_key = nil
#          end
#        end

        instance_eval(&block)
      end
    end
  end
end
