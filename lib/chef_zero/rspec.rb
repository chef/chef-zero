require 'thin'
require 'tempfile'
require 'chef_zero/server'
require 'chef/config'

module ChefZero
  module RSpec
    def when_the_chef_server(description, &block)
      context "When the Chef server #{description}" do
        before :each do
          raise "Attempt to create multiple servers in one test" if @server
          # Set up configuration so that clients will point to the server
          Thin::Logging.silent = true
          @chef_zero_server = ChefZero::Server.new(:port => 8889)
          Chef::Config.chef_server_url = @chef_zero_server.url
          Chef::Config.node_name = 'admin'
          @chef_zero_client_key = Tempfile.new(['chef_zero_client_key', '.pem'])
          @chef_zero_client_key.write(ChefZero::PRIVATE_KEY)
          @chef_zero_client_key.close
          Chef::Config.client_key = @chef_zero_client_key

          # Start the server
          @chef_zero_server.start_background
        end

        def self.client(name, client)
          before(:each) { @chef_zero_server.load_data({ 'clients' => { name => client }}) }
        end

        def self.cookbook(name, version, cookbook)
          before(:each) { @chef_zero_server.load_data({ 'cookbooks' => { "#{name}-#{version}" => cookbook }}) }
        end

        def self.data_bag(name, data_bag)
          before(:each) { @chef_zero_server.load_data({ 'data' => { name => data_bag }}) }
        end

        def self.environment(name, environment)
          before(:each) { @chef_zero_server.load_data({ 'environments' => { name => environment }}) }
        end

        def self.node(name, node)
          before(:each) { @chef_zero_server.load_data({ 'nodes' => { name => node }}) }
        end

        def self.role(name, role)
          before(:each) { @chef_zero_server.load_data({ 'roles' => { name => role }}) }
        end

        def self.user(name, user)
          before(:each) { @chef_zero_server.load_data({ 'users' => { name => user }}) }
        end

        after :each do
          if @chef_zero_server
            @chef_zero_server.stop
            @chef_zero_server = nil
          end
          if @chef_zero_client_key
            @chef_zero_client_key.unlink
            @chef_zero_client_key = nil
          end
        end

        instance_eval(&block)
      end
    end
  end
end
