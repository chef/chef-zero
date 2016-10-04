require "tempfile"
require "chef_zero/server"
require "chef_zero/rest_request"

module ChefZero
  module RSpec
    module RSpecClassMethods
      attr_accessor :server
      attr_accessor :client_key
      attr_reader :request_log

      def clear_request_log
        @request_log = []
      end

      def set_server_options(chef_server_options)
        if server && chef_server_options != server.options
          server.stop
          self.server = nil
        end

        unless server
          # TODO: can this be logged easily?
          # pp :zero_opts => chef_server_options

          # Set up configuration so that clients will point to the server
          self.server = ChefZero::Server.new(chef_server_options)
          self.client_key = Tempfile.new(["chef_zero_client_key", ".pem"])
          client_key.write(ChefZero::PRIVATE_KEY)
          client_key.close
          # Start the server
          server.start_background
          server.on_response do |request, response|
            request_log << [ request, response ]
          end
        else
          server.clear_data
        end
        clear_request_log
      end
    end
    extend RSpecClassMethods

    def when_the_chef_server(description, *tags, &block)
      context "When the Chef server #{description}", *tags do
        extend WhenTheChefServerClassMethods
        include WhenTheChefServerInstanceMethods

        # Take the passed-in options

        define_singleton_method(:chef_server_options) do
          @chef_server_options ||= begin
            _chef_server_options = { port: 8900, signals: false, log_requests: true }
            _chef_server_options = _chef_server_options.merge(tags.last) if tags.last.is_a?(Hash)
            _chef_server_options = _chef_server_options.freeze
          end
        end

        # Merge in chef_server_options from let(:chef_server_options)
        def chef_server_options
          chef_server_options = self.class.chef_server_options.dup
          chef_server_options = chef_server_options.merge(chef_zero_opts) if self.respond_to?(:chef_zero_opts)
          chef_server_options
        end

        before chef_server_options[:server_scope] do
          if chef_server_options[:server_scope] != self.class.chef_server_options[:server_scope]
            raise "server_scope: #{chef_server_options[:server_scope]} will not be honored: it can only be set on when_the_chef_server!"
          end
          Log.info("Starting Chef server with options #{chef_server_options}")

          ChefZero::RSpec.set_server_options(chef_server_options)

          if chef_server_options[:organization]
            organization chef_server_options[:organization]
          end

          if defined?(Chef::Config)
            @old_chef_server_url = Chef::Config.chef_server_url
            @old_node_name = Chef::Config.node_name
            @old_client_key = Chef::Config.client_key
            if chef_server_options[:organization]
              Chef::Config.chef_server_url = "#{ChefZero::RSpec.server.url}/organizations/#{chef_server_options[:organization]}"
            else
              Chef::Config.chef_server_url = ChefZero::RSpec.server.url
            end
            Chef::Config.node_name = "admin"
            Chef::Config.client_key = ChefZero::RSpec.client_key.path
            Chef::Config.http_retry_count = 0
          end
        end

        if defined?(Chef::Config)
          after chef_server_options[:server_scope] do
            Chef::Config.chef_server_url = @old_chef_server_url
            Chef::Config.node_name = @old_node_name
            Chef::Config.client_key = @old_client_key
          end
        end

        instance_eval(&block)
      end
    end

    module WhenTheChefServerClassMethods
      def organization(name, org = "{}", &block)
        before(chef_server_options[:server_scope]) { organization(name, org, &block) }
      end

      def acl_for(path, data)
        before(chef_server_options[:server_scope]) { acl_for(path, data) }
      end

      def client(name, data, &block)
        before(chef_server_options[:server_scope]) { client(name, data, &block) }
      end

      def container(name, data, &block)
        before(chef_server_options[:server_scope]) { container(name, data, &block) }
      end

      def cookbook(name, version, data = {}, options = {}, &block)
        before(chef_server_options[:server_scope]) do
          cookbook(name, version, data, &block)
        end
      end

      def cookbook_artifact(name, identifier, data = {}, &block)
        before(chef_server_options[:server_scope]) { cookbook_artifact(name, identifier, data, &block) }
      end

      def data_bag(name, data, &block)
        before(chef_server_options[:server_scope]) { data_bag(name, data, &block) }
      end

      def environment(name, data, &block)
        before(chef_server_options[:server_scope]) { environment(name, data, &block) }
      end

      def group(name, data, &block)
        before(chef_server_options[:server_scope]) { group(name, data, &block) }
      end

      def node(name, data, &block)
        before(chef_server_options[:server_scope]) { node(name, data, &block) }
      end

      def org_invite(*usernames)
        before(chef_server_options[:server_scope]) { org_invite(*usernames) }
      end

      def org_member(*usernames)
        before(chef_server_options[:server_scope]) { org_member(*usernames) }
      end

      def policy(name, data, &block)
        before(chef_server_options[:server_scope]) { policy(name, data, &block) }
      end

      def policy_group(name, data, &block)
        before(chef_server_options[:server_scope]) { policy_group(name, data, &block) }
      end

      def role(name, data, &block)
        before(chef_server_options[:server_scope]) { role(name, data, &block) }
      end

      def sandbox(name, data, &block)
        before(chef_server_options[:server_scope]) { sandbox(name, data, &block) }
      end

      def user(name, data, &block)
        before(chef_server_options[:server_scope]) { user(name, data, &block) }
      end
    end

    module WhenTheChefServerInstanceMethods
      def organization(name, org = "{}", &block)
        ChefZero::RSpec.server.data_store.set([ "organizations", name, "org" ], dejsonize(org), :create_dir, :create)
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

      def acl_for(path, data)
        ChefZero::RSpec.server.load_data({ "acls" => { path => data } }, current_org)
      end

      def acl(data)
        acl_for(@current_object_path, data)
      end

      def client(name, data, &block)
        with_object_path("clients/#{name}") do
          ChefZero::RSpec.server.load_data({ "clients" => { name => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def container(name, data, &block)
        with_object_path("containers/#{name}") do
          ChefZero::RSpec.server.load_data({ "containers" => { name => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def cookbook(name, version, data = {}, options = {}, &block)
        with_object_path("cookbooks/#{name}") do
          # If you didn't specify metadata.rb, we generate it for you. If you
          # explicitly set it to nil, that means you don't want it at all.
          if data.has_key?("metadata.rb")
            if data["metadata.rb"].nil?
              data.delete("metadata.rb")
            end
          else
            data["metadata.rb"] = "name #{name.inspect}; version #{version.inspect}"
          end
          ChefZero::RSpec.server.load_data({ "cookbooks" => { "#{name}-#{version}" => data.merge(options) } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def cookbook_artifact(name, identifier, data = {}, &block)
        with_object_path("cookbook_artifacts/#{name}") do
          # If you didn't specify metadata.rb, we generate it for you. If you
          # explicitly set it to nil, that means you don't want it at all.
          if data.has_key?("metadata.rb")
            if data["metadata.rb"].nil?
              data.delete("metadata.rb")
            end
          else
            data["metadata.rb"] = "name #{name.inspect}"
          end
          ChefZero::RSpec.server.load_data({ "cookbook_artifacts" => { "#{name}-#{identifier}" => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def data_bag(name, data, &block)
        with_object_path("data/#{name}") do
          ChefZero::RSpec.server.load_data({ "data" => { name => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def environment(name, data, &block)
        with_object_path("environments/#{name}") do
          ChefZero::RSpec.server.load_data({ "environments" => { name => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def group(name, data, &block)
        with_object_path("groups/#{name}") do
          ChefZero::RSpec.server.load_data({ "groups" => { name => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def node(name, data, &block)
        with_object_path("nodes/#{name}") do
          ChefZero::RSpec.server.load_data({ "nodes" => { name => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def org_invite(*usernames)
        ChefZero::RSpec.server.load_data({ "invites" => usernames }, current_org)
      end

      def org_member(*usernames)
        ChefZero::RSpec.server.load_data({ "members" => usernames }, current_org)
      end

      def policy(name, version, data, &block)
        with_object_path("policies/#{name}") do
          ChefZero::RSpec.server.load_data({ "policies" => { name => { version => data } } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def policy_group(name, data, &block)
        with_object_path("policy_groups/#{name}") do
          ChefZero::RSpec.server.load_data({ "policy_groups" => { name => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def role(name, data, &block)
        with_object_path("roles/#{name}") do
          ChefZero::RSpec.server.load_data({ "roles" => { name => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def sandbox(name, data, &block)
        with_object_path("sandboxes/#{name}") do
          ChefZero::RSpec.server.load_data({ "sandboxes" => { name => data } }, current_org)
          instance_eval(&block) if block_given?
        end
      end

      def user(name, data, &block)
        if ChefZero::RSpec.server.options[:osc_compat]
          with_object_path("users/#{name}") do
            ChefZero::RSpec.server.load_data({ "users" => { name => data } }, current_org)
            instance_eval(&block) if block_given?
          end
        else
          old_object_path = @current_object_path
          @current_object_path = "users/#{name}"
          begin
            ChefZero::RSpec.server.load_data({ "users" => { name => data } }, current_org)
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
    end
  end
end
