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
      if tags.last.is_a?(Hash)
        opts = tags.last
      else
        opts = {}
      end
      context "When the Chef server #{description}", *tags do
        before :each do

          default_opts = {:port => 8900, :signals => false, :log_requests => true}
          server_opts = if self.respond_to?(:chef_zero_opts)
            default_opts.merge(chef_zero_opts)
          else
            default_opts
          end
          server_opts = server_opts.merge(opts)

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

        def self.organization(name, org = '{}', &block)
          before(:each) { organization(name, org, &block) }
        end

        def organization(name, org = '{}', &block)
          ChefZero::RSpec.server.data_store.set([ 'organizations', name, 'org' ], dejsonize(org), :create_dir, :create)
          prev_org_name = @current_org
          @current_org = name
          prev_object_path = @current_object_path
          @current_object_path = "organizations/#{name}"
          if block_given?
            begin
              instance_eval(&block)
            ensure
              @current_org = prev_org_name
              @current_object_path = prev_object_path
            end
          end
        end

        def self.acl_for(path, data)
          before(:each) { acl_for(path, data) }
        end

        def acl_for(path, data)
          ChefZero::RSpec.server.load_data({ 'acls' => { path => data } }, current_org)
        end

        def acl(data)
          acl_for(@current_object_path, data)
        end

        def self.client(name, data, &block)
          before(:each) { client(name, data, &block) }
        end

        def client(name, data, &block)
          with_object_path("clients/#{name}") do
            ChefZero::RSpec.server.load_data({ 'clients' => { name => data } }, current_org)
            instance_eval(&block) if block_given?
          end
        end

        def self.container(name, data, &block)
          before(:each) { container(name, data, &block) }
        end

        def container(name, data, &block)
          with_object_path("containers/#{name}") do
            ChefZero::RSpec.server.load_data({ 'containers' => { name => data } }, current_org)
            instance_eval(&block) if block_given?
          end
        end

        def self.cookbook(name, version, data = {}, options = {}, &block)
          before(:each) do
            cookbook(name, version, data, &block)
          end
        end

        def cookbook(name, version, data = {}, options = {}, &block)
          with_object_path("cookbooks/#{name}") do
            if data.has_key?('metadata.rb')
              if data['metadata.rb'].nil?
                data.delete('metadata.rb')
              end
            else
              data['metadata.rb'] = "name #{name.inspect}; version #{version.inspect}"
            end
            ChefZero::RSpec.server.load_data({ 'cookbooks' => { "#{name}-#{version}" => data.merge(options) }}, current_org)
            instance_eval(&block) if block_given?
          end
        end

        def self.data_bag(name, data, &block)
          before(:each) { data_bag(name, data, &block) }
        end

        def data_bag(name, data, &block)
          with_object_path("data/#{name}") do
            ChefZero::RSpec.server.load_data({ 'data' => { name => data }}, current_org)
            instance_eval(&block) if block_given?
          end
        end

        def self.environment(name, data, &block)
          before(:each) { environment(name, data, &block) }
        end

        def environment(name, data, &block)
          with_object_path("environments/#{name}") do
            ChefZero::RSpec.server.load_data({ 'environments' => { name => data } }, current_org)
            instance_eval(&block) if block_given?
          end
        end

        def self.group(name, data, &block)
          before(:each) { group(name, data, &block) }
        end

        def group(name, data, &block)
          with_object_path("groups/#{name}") do
            ChefZero::RSpec.server.load_data({ 'groups' => { name => data } }, current_org)
            instance_eval(&block) if block_given?
          end
        end

        def self.node(name, data, &block)
          before(:each) { node(name, data, &block) }
        end

        def node(name, data, &block)
          with_object_path("nodes/#{name}") do
            ChefZero::RSpec.server.load_data({ 'nodes' => { name => data } }, current_org)
            instance_eval(&block) if block_given?
          end
        end

        def self.org_invite(*usernames)
          before(:each) { org_invite(*usernames) }
        end

        def org_invite(*usernames)
          ChefZero::RSpec.server.load_data({ 'invites' => usernames }, current_org)
        end

        def self.org_member(*usernames)
          before(:each) { org_member(*usernames) }
        end

        def org_member(*usernames)
          ChefZero::RSpec.server.load_data({ 'members' => usernames }, current_org)
        end

        def self.role(name, data, &block)
          before(:each) { role(name, data, &block) }
        end

        def role(name, data, &block)
          with_object_path("roles/#{name}") do
            ChefZero::RSpec.server.load_data({ 'roles' => { name => data } }, current_org)
            instance_eval(&block) if block_given?
          end
        end

        def self.sandbox(name, data, &block)
          before(:each) { sandbox(name, data, &block) }
        end

        def sandbox(name, data, &block)
          with_object_path("sandboxes/#{name}") do
            ChefZero::RSpec.server.load_data({ 'sandboxes' => { name => data } }, current_org)
            instance_eval(&block) if block_given?
          end
        end

        def self.user(name, data, &block)
          before(:each) { user(name, data, &block) }
        end

        def user(name, data, &block)
          if ChefZero::RSpec.server.options[:osc_compat]
            with_object_path("users/#{name}") do
              ChefZero::RSpec.server.load_data({ 'users' => { name => data }}, current_org)
              instance_eval(&block) if block_given?
            end
          else
            old_object_path = @current_object_path
            @current_object_path = "users/#{name}"
            begin
              ChefZero::RSpec.server.load_data({ 'users' => { name => data }}, current_org)
              instance_eval(&block) if block_given?
            ensure
              @current_object_path = old_object_path
            end
          end
        end

        def dejsonize(data)
          if data.is_a?(String)
            data
          else
            FFI_Yajl::Encoder.encode(data, :pretty => true)
          end
        end

        def current_org
          @current_org || ChefZero::RSpec.server.options[:single_org] || nil
        end

        def with_object_path(object_path)
          old_object_path = @current_object_path
          @current_object_path = object_path
          begin
            yield if block_given?
          end
          @current_object_path = old_object_path
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
