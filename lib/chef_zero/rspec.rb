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
          unless ChefZero::RSpec.server
            # Set up configuration so that clients will point to the server
            ChefZero::RSpec.server = ChefZero::Server.new(:port => 8889, :signals => false, :log_requests => true)
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

        def self.client(name, client)
          before(:each) { ChefZero::RSpec.server.load_data({ 'clients' => { name => client }}) }
        end

        def self.cookbook(name, version, cookbook, options = {})
          before(:each) { ChefZero::RSpec.server.load_data({ 'cookbooks' => { "#{name}-#{version}" => cookbook.merge(options) }}) }
        end

        def self.data_bag(name, data_bag)
          before(:each) { ChefZero::RSpec.server.load_data({ 'data' => { name => data_bag }}) }
        end

        def self.environment(name, environment)
          before(:each) { ChefZero::RSpec.server.load_data({ 'environments' => { name => environment }}) }
        end

        def self.node(name, node)
          before(:each) { ChefZero::RSpec.server.load_data({ 'nodes' => { name => node }}) }
        end

        def self.role(name, role)
          before(:each) { ChefZero::RSpec.server.load_data({ 'roles' => { name => role }}) }
        end

        def self.user(name, user)
          before(:each) { ChefZero::RSpec.server.load_data({ 'users' => { name => user }}) }
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
