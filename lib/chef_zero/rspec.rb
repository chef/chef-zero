require 'thin'
require 'tempfile'
require 'chef_zero/server'
require 'chef/config'

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

    def when_the_chef_server(description, &block)
      context "When the Chef server #{description}" do
        before :each do
          unless ChefZero::RSpec.server
            # Set up configuration so that clients will point to the server
            Thin::Logging.silent = true
            ChefZero::RSpec.server = ChefZero::Server.new(:port => 8889)
            ChefZero::RSpec.client_key = Tempfile.new(['chef_zero_client_key', '.pem'])
            ChefZero::RSpec.client_key.write(ChefZero::PRIVATE_KEY)
            ChefZero::RSpec.client_key.close
            # Start the server
            ChefZero::RSpec.server.start_background
          else
            ChefZero::RSpec.server.clear_data
          end

          Chef::Config.chef_server_url = ChefZero::RSpec.server.url
          Chef::Config.node_name = 'admin'
          Chef::Config.client_key = ChefZero::RSpec.client_key
        end

        def self.client(name, client)
          before(:each) { ChefZero::RSpec.server.load_data({ 'clients' => { name => client }}) }
        end

        def self.cookbook(name, version, cookbook)
          before(:each) { ChefZero::RSpec.server.load_data({ 'cookbooks' => { "#{name}-#{version}" => cookbook }}) }
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
