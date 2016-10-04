#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "openssl"
require "open-uri"
require "rubygems"
require "timeout"
require "stringio"

require "rack"
require "webrick"
require "webrick/https"

require "chef_zero"
require "chef_zero/socketless_server_map"
require "chef_zero/chef_data/cookbook_data"
require "chef_zero/chef_data/acl_path"
require "chef_zero/rest_router"
require "chef_zero/data_store/memory_store_v2"
require "chef_zero/data_store/v1_to_v2_adapter"
require "chef_zero/data_store/default_facade"
require "chef_zero/version"

require "chef_zero/endpoints/rest_list_endpoint"
require "chef_zero/endpoints/authenticate_user_endpoint"
require "chef_zero/endpoints/acls_endpoint"
require "chef_zero/endpoints/acl_endpoint"
require "chef_zero/endpoints/actor_endpoint"
require "chef_zero/endpoints/actors_endpoint"
require "chef_zero/endpoints/actor_key_endpoint"
require "chef_zero/endpoints/organization_user_key_endpoint"
require "chef_zero/endpoints/organization_user_default_key_endpoint"
require "chef_zero/endpoints/organization_user_keys_endpoint"
require "chef_zero/endpoints/actor_default_key_endpoint"
require "chef_zero/endpoints/actor_keys_endpoint"
require "chef_zero/endpoints/cookbooks_endpoint"
require "chef_zero/endpoints/cookbook_endpoint"
require "chef_zero/endpoints/cookbook_version_endpoint"
require "chef_zero/endpoints/cookbook_artifacts_endpoint"
require "chef_zero/endpoints/cookbook_artifact_endpoint"
require "chef_zero/endpoints/cookbook_artifact_identifier_endpoint"
require "chef_zero/endpoints/containers_endpoint"
require "chef_zero/endpoints/container_endpoint"
require "chef_zero/endpoints/controls_endpoint"
require "chef_zero/endpoints/dummy_endpoint"
require "chef_zero/endpoints/data_bags_endpoint"
require "chef_zero/endpoints/data_bag_endpoint"
require "chef_zero/endpoints/data_bag_item_endpoint"
require "chef_zero/endpoints/groups_endpoint"
require "chef_zero/endpoints/group_endpoint"
require "chef_zero/endpoints/environment_endpoint"
require "chef_zero/endpoints/environment_cookbooks_endpoint"
require "chef_zero/endpoints/environment_cookbook_endpoint"
require "chef_zero/endpoints/environment_cookbook_versions_endpoint"
require "chef_zero/endpoints/environment_nodes_endpoint"
require "chef_zero/endpoints/environment_recipes_endpoint"
require "chef_zero/endpoints/environment_role_endpoint"
require "chef_zero/endpoints/license_endpoint"
require "chef_zero/endpoints/node_endpoint"
require "chef_zero/endpoints/nodes_endpoint"
require "chef_zero/endpoints/node_identifiers_endpoint"
require "chef_zero/endpoints/organizations_endpoint"
require "chef_zero/endpoints/organization_endpoint"
require "chef_zero/endpoints/organization_association_requests_endpoint"
require "chef_zero/endpoints/organization_association_request_endpoint"
require "chef_zero/endpoints/organization_authenticate_user_endpoint"
require "chef_zero/endpoints/organization_users_endpoint"
require "chef_zero/endpoints/organization_user_endpoint"
require "chef_zero/endpoints/organization_validator_key_endpoint"
require "chef_zero/endpoints/policies_endpoint"
require "chef_zero/endpoints/policy_endpoint"
require "chef_zero/endpoints/policy_revisions_endpoint"
require "chef_zero/endpoints/policy_revision_endpoint"
require "chef_zero/endpoints/policy_groups_endpoint"
require "chef_zero/endpoints/policy_group_endpoint"
require "chef_zero/endpoints/policy_group_policy_endpoint"
require "chef_zero/endpoints/principal_endpoint"
require "chef_zero/endpoints/role_endpoint"
require "chef_zero/endpoints/role_environments_endpoint"
require "chef_zero/endpoints/sandboxes_endpoint"
require "chef_zero/endpoints/sandbox_endpoint"
require "chef_zero/endpoints/searches_endpoint"
require "chef_zero/endpoints/search_endpoint"
require "chef_zero/endpoints/system_recovery_endpoint"
require "chef_zero/endpoints/user_association_requests_endpoint"
require "chef_zero/endpoints/user_association_requests_count_endpoint"
require "chef_zero/endpoints/user_association_request_endpoint"
require "chef_zero/endpoints/user_organizations_endpoint"
require "chef_zero/endpoints/file_store_file_endpoint"
require "chef_zero/endpoints/not_found_endpoint"
require "chef_zero/endpoints/version_endpoint"
require "chef_zero/endpoints/server_api_version_endpoint"

module ChefZero

  class Server

    DEFAULT_OPTIONS = {
      :host => ["127.0.0.1"],
      :port => 8889,
      :log_level => :warn,
      :generate_real_keys => true,
      :single_org => "chef",
      :ssl => false,
    }.freeze

    GLOBAL_ENDPOINTS = [
      "/license",
      "/version",
      "/server_api_version",
    ]

    def initialize(options = {})
      @options = DEFAULT_OPTIONS.merge(options)
      if @options[:single_org] && !@options.has_key?(:osc_compat)
        @options[:osc_compat] = true
      end
      @options.freeze
      ChefZero::Log.level = @options[:log_level].to_sym
      @app = nil
    end

    # @return [Hash]
    attr_reader :options

    # @return [Integer]
    def port
      if @port
        @port
      # If options[:port] is not an Array or an Enumerable, it is just an Integer.
      elsif !options[:port].respond_to?(:each)
        options[:port]
      else
        raise "port cannot be determined until server is started"
      end
    end

    # @return [WEBrick::HTTPServer]
    attr_reader :server

    include ChefZero::Endpoints

    #
    # The URL for this Chef Zero server. If the given host is an IPV6 address,
    # it is escaped in brackets according to RFC-2732.
    #
    # @see http://www.ietf.org/rfc/rfc2732.txt RFC-2732
    #
    # @return [String]
    #
    def url
      sch = @options[:ssl] ? "https" : "http"
      hosts = Array(@options[:host])
      @url ||= if hosts.first.include?(":")
                 URI("#{sch}://[#{hosts.first}]:#{port}").to_s
               else
                 URI("#{sch}://#{hosts.first}:#{port}").to_s
               end
    end

    def local_mode_url
      raise "Port not yet set, cannot generate URL" unless port.kind_of?(Integer)
      "chefzero://localhost:#{port}"
    end

    #
    # The data store for this server (default is in-memory).
    #
    # @return [ChefZero::DataStore]
    #
    def data_store
      @data_store ||= begin
        result = @options[:data_store] || DataStore::DefaultFacade.new(DataStore::MemoryStoreV2.new, options[:single_org], options[:osc_compat])
        if options[:single_org]

          if !result.respond_to?(:interface_version) || result.interface_version == 1
            result = ChefZero::DataStore::V1ToV2Adapter.new(result, options[:single_org])
            result = ChefZero::DataStore::DefaultFacade.new(result, options[:single_org], options[:osc_compat])
          end

        else
          if !result.respond_to?(:interface_version) || result.interface_version == 1
            raise "Multi-org not supported by data store #{result}!"
          end
        end

        result
      end
    end

    #
    # Boolean method to determine if real Public/Private keys should be
    # generated.
    #
    # @return [Boolean]
    #   true if real keys should be created, false otherwise
    #
    def generate_real_keys?
      !!@options[:generate_real_keys]
    end

    #
    # Start a Chef Zero server in the current thread. You can stop this server
    # by canceling the current thread.
    #
    # @param [Boolean|IO] publish
    #   publish the server information to the publish parameter or to STDOUT if it's "true"
    #
    # @return [nil]
    #   this method will block the main thread until interrupted
    #
    def start(publish = true)
      publish = publish[:publish] if publish.is_a?(Hash) # Legacy API

      if publish
        output = publish.respond_to?(:puts) ? publish : STDOUT
        output.puts <<-EOH.gsub(/^ {10}/, "")
          >> Starting Chef Zero (v#{ChefZero::VERSION})...
        EOH
      end

      thread = start_background

      if publish
        output = publish.respond_to?(:puts) ? publish : STDOUT
        output.puts <<-EOH.gsub(/^ {10}/, "")
          >> WEBrick (v#{WEBrick::VERSION}) on Rack (v#{Rack.release}) is listening at #{url}
          >> Press CTRL+C to stop

        EOH
      end

      %w{INT TERM}.each do |signal|
        Signal.trap(signal) do
          puts "\n>> Stopping Chef Zero..."
          @server.shutdown
        end
      end

      # Move the background process to the main thread
      thread.join
    end

    #
    # Start a Chef Zero server in a forked process. This method returns the PID
    # to the forked process.
    #
    # @param [Fixnum] wait
    #   the number of seconds to wait for the server to start
    #
    # @return [Thread]
    #   the thread the background process is running in
    #
    def listen(hosts, port)
      hosts.each do |host|
        @server.listen(host, port)
      end
      true
    rescue Errno::EADDRINUSE
      ChefZero::Log.warn("Port #{port} not available")
      @server.listeners.each { |l| l.close }
      @server.listeners.clear
      false
    end

    def start_background(wait = 5)
      @server = WEBrick::HTTPServer.new(
        :DoNotListen => true,
        :AccessLog   => [],
        :Logger      => WEBrick::Log.new(StringIO.new, 7),
        :RequestTimeout => 300,
        :SSLEnable => options[:ssl],
        :SSLOptions => ssl_opts,
        :SSLCertName => [ [ "CN", WEBrick::Utils.getservername ] ],
        :StartCallback => proc do
          @running = true
        end
      )
      ENV["HTTPS"] = "on" if options[:ssl]
      @server.mount("/", Rack::Handler::WEBrick, app)

      # Pick a port
      # If options[:port] can be an Enumerator, an Array, or an Integer,
      # we need something that can respond to .each (Enum and Array can already).
      Array(options[:port]).each do |port|
        if listen(Array(options[:host]), port)
          @port = port
          break
        end
      end
      if !@port
        raise Errno::EADDRINUSE,
          "No port in :port range #{options[:port]} is available"
      end

      # Start the server in the background
      @thread = Thread.new do
        begin
          Thread.current.abort_on_exception = true
          @server.start
        ensure
          @port = nil
          @running = false
        end
      end

      # Do not return until the web server is genuinely started.
      sleep(0.01) while !@running && @thread.alive?

      SocketlessServerMap.instance.register_port(@port, self)

      @thread
    end

    def start_socketless
      @port = SocketlessServerMap.instance.register_no_listen_server(self)
    end

    def handle_socketless_request(request_env)
      app.call(request_env)
    end

    #
    # Boolean method to determine if the server is currently ready to accept
    # requests. This method will attempt to make an HTTP request against the
    # server. If this method returns true, you are safe to make a request.
    #
    # @return [Boolean]
    #   true if the server is accepting requests, false otherwise
    #
    def running?
      !@server.nil? && @running && @server.status == :Running
    end

    #
    # Gracefully stop the Chef Zero server.
    #
    # @param [Fixnum] wait
    #   the number of seconds to wait before raising force-terminating the
    #   server
    #
    def stop(wait = 5)
      if @running
        @server.shutdown if @server
        @thread.join(wait) if @thread
      end
    rescue Timeout::Error
      if @thread
        ChefZero::Log.error("Chef Zero did not stop within #{wait} seconds! Killing...")
        @thread.kill
        SocketlessServerMap.deregister(port)
      end
    ensure
      @server = nil
      @thread = nil
    end

    def gen_key_pair
      if generate_real_keys?
        private_key = OpenSSL::PKey::RSA.new(2048)
        public_key = private_key.public_key.to_s
        public_key.sub!(/^-----BEGIN RSA PUBLIC KEY-----/, "-----BEGIN PUBLIC KEY-----")
        public_key.sub!(/-----END RSA PUBLIC KEY-----(\s+)$/, '-----END PUBLIC KEY-----\1')
        [private_key.to_s, public_key]
      else
        [PRIVATE_KEY, PUBLIC_KEY]
      end
    end

    def on_request(&block)
      @on_request_proc = block
    end

    def on_response(&block)
      @on_response_proc = block
    end

    # Load data in a nice, friendly form:
    # {
    #   'roles' => {
    #     'desert' => '{ "description": "Hot and dry"' },
    #     'rainforest' => { "description" => 'Wet and humid' }
    #   },
    #   'cookbooks' => {
    #     'apache2-1.0.1' => {
    #       'templates' => { 'default' => { 'blah.txt' => 'hi' }}
    #       'recipes' => { 'default.rb' => 'template "blah.txt"' }
    #       'metadata.rb' => 'depends "mysql"'
    #     },
    #     'apache2-1.2.0' => {
    #       'templates' => { 'default' => { 'blah.txt' => 'lo' }}
    #       'recipes' => { 'default.rb' => 'template "blah.txt"' }
    #       'metadata.rb' => 'depends "mysql"'
    #     },
    #     'mysql' => {
    #       'recipes' => { 'default.rb' => 'file { contents "hi" }' },
    #       'metadata.rb' => 'version "1.0.0"'
    #     }
    #   }
    # }
    def load_data(contents, org_name = nil)
      org_name ||= options[:single_org]
      if org_name.nil? && contents.keys != [ "users" ]
        raise "Must pass an org name to load_data or run in single_org mode"
      end

      %w{clients containers environments groups nodes roles sandboxes}.each do |data_type|
        if contents[data_type]
          dejsonize_children(contents[data_type]).each_pair do |name, data|
            data_store.set(["organizations", org_name, data_type, name], data, :create)
          end
        end
      end

      if contents["users"]
        dejsonize_children(contents["users"]).each_pair do |name, data|
          if options[:osc_compat]
            data_store.set(["organizations", org_name, "users", name], data, :create)
          else
            # Create the user and put them in the org
            data_store.set(["users", name], data, :create)
            if org_name
              data_store.set(["organizations", org_name, "users", name], "{}", :create)
            end
          end
        end
      end

      if contents["members"]
        contents["members"].each do |name|
          data_store.set(["organizations", org_name, "users", name], "{}", :create)
        end
      end

      if contents["invites"]
        contents["invites"].each do |name|
          data_store.set(["organizations", org_name, "association_requests", name], "{}", :create)
        end
      end

      if contents["acls"]
        dejsonize_children(contents["acls"]).each do |path, acl|
          path = [ "organizations", org_name ] + path.split("/")
          path = ChefData::AclPath.get_acl_data_path(path)
          ChefZero::RSpec.server.data_store.set(path, acl)
        end
      end

      if contents["data"]
        contents["data"].each_pair do |key, data_bag|
          data_store.create_dir(["organizations", org_name, "data"], key, :recursive)
          dejsonize_children(data_bag).each do |item_name, item|
            data_store.set(["organizations", org_name, "data", key, item_name], item, :create)
          end
        end
      end

      if contents["policies"]
        contents["policies"].each_pair do |policy_name, policy_struct|
          # data_store.create_dir(['organizations', org_name, 'policies', policy_name], "revisions", :recursive)
          dejsonize_children(policy_struct).each do |revision, policy_data|
            data_store.set(["organizations", org_name, "policies", policy_name,
                            "revisions", revision], policy_data, :create, :create_dir)
          end
        end
      end

      if contents["policy_groups"]
        contents["policy_groups"].each_pair do |group_name, group|
          group["policies"].each do |policy_name, policy_revision|
            data_store.set(["organizations", org_name, "policy_groups", group_name, "policies", policy_name], FFI_Yajl::Encoder.encode(policy_revision["revision_id"], :pretty => true), :create, :create_dir)
          end
        end
      end

      %w{cookbooks cookbook_artifacts}.each do |cookbook_type|
        if contents[cookbook_type]
          contents[cookbook_type].each_pair do |name_version, cookbook|
            if cookbook_type == "cookbook_artifacts"
              name, dash, identifier = name_version.rpartition("-")
              cookbook_data = ChefData::CookbookData.to_hash(cookbook, name, identifier)
            elsif name_version =~ /(.+)-(\d+\.\d+\.\d+)$/
              cookbook_data = ChefData::CookbookData.to_hash(cookbook, $1, $2)
            else
              cookbook_data = ChefData::CookbookData.to_hash(cookbook, name_version)
            end
            raise "No version specified" if !cookbook_data[:version]
            data_store.create_dir(["organizations", org_name, cookbook_type], cookbook_data[:cookbook_name], :recursive)
            data_store.set(["organizations", org_name, cookbook_type, cookbook_data[:cookbook_name], cookbook_data[:version]], FFI_Yajl::Encoder.encode(cookbook_data, :pretty => true), :create)
            cookbook_data.values.each do |files|
              next unless files.is_a? Array
              files.each do |file|
                data_store.set(["organizations", org_name, "file_store", "checksums", file[:checksum]], get_file(cookbook, file[:path]), :create)
              end
            end
          end
        end
      end
    end

    def clear_data
      data_store.clear
    end

    def request_handler(&block)
      @request_handler = block
    end

    def to_s
      "#<#{self.class} #{url}>"
    end

    def inspect
      "#<#{self.class} @url=#{url.inspect}>"
    end

    private

    def endpoints
      result = if options[:osc_compat]
                 # OSC-only
                 [
                   [ "/organizations/*/users", ActorsEndpoint.new(self) ],
                   [ "/organizations/*/users/*", ActorEndpoint.new(self) ],
                   [ "/organizations/*/authenticate_user", OrganizationAuthenticateUserEndpoint.new(self) ],
                 ]
               else
                 # EC-only
                 [
                   [ "/organizations/*/users", OrganizationUsersEndpoint.new(self) ],
                   [ "/organizations/*/users/*", OrganizationUserEndpoint.new(self) ],
                   [ "/users", ActorsEndpoint.new(self, "username") ],
                   [ "/users/*", ActorEndpoint.new(self, "username") ],
                   [ "/users/*/_acl", AclsEndpoint.new(self) ],
                   [ "/users/*/_acl/*", AclEndpoint.new(self) ],
                   [ "/users/*/association_requests", UserAssociationRequestsEndpoint.new(self) ],
                   [ "/users/*/association_requests/count", UserAssociationRequestsCountEndpoint.new(self) ],
                   [ "/users/*/association_requests/*", UserAssociationRequestEndpoint.new(self) ],
                   [ "/users/*/keys", ActorKeysEndpoint.new(self) ],
                   [ "/users/*/keys/default", ActorDefaultKeyEndpoint.new(self) ],
                   [ "/users/*/keys/*", ActorKeyEndpoint.new(self) ],
                   [ "/users/*/organizations", UserOrganizationsEndpoint.new(self) ],
                   [ "/authenticate_user", AuthenticateUserEndpoint.new(self) ],
                   [ "/system_recovery", SystemRecoveryEndpoint.new(self) ],
                   [ "/license", LicenseEndpoint.new(self) ],
                   [ "/organizations", OrganizationsEndpoint.new(self) ],
                   [ "/organizations/*", OrganizationEndpoint.new(self) ],
                   [ "/organizations/*/_validator_key", OrganizationValidatorKeyEndpoint.new(self) ],
                   [ "/organizations/*/association_requests", OrganizationAssociationRequestsEndpoint.new(self) ],
                   [ "/organizations/*/association_requests/*", OrganizationAssociationRequestEndpoint.new(self) ],
                   [ "/organizations/*/containers", ContainersEndpoint.new(self) ],
                   [ "/organizations/*/containers/*", ContainerEndpoint.new(self) ],
                   [ "/organizations/*/groups", GroupsEndpoint.new(self) ],
                   [ "/organizations/*/groups/*", GroupEndpoint.new(self) ],
                   [ "/organizations/*/organization/_acl", AclsEndpoint.new(self) ],
                   [ "/organizations/*/organizations/_acl", AclsEndpoint.new(self) ],
                   [ "/organizations/*/*/*/_acl", AclsEndpoint.new(self) ],
                   [ "/organizations/*/organization/_acl/*", AclEndpoint.new(self) ],
                   [ "/organizations/*/organizations/_acl/*", AclEndpoint.new(self) ],
                   [ "/organizations/*/*/*/_acl/*", AclEndpoint.new(self) ],
                 ]
               end
      result + [
        # Both
        [ "/dummy", DummyEndpoint.new(self) ],
        [ "/organizations/*/clients", ActorsEndpoint.new(self) ],
        [ "/organizations/*/clients/*", ActorEndpoint.new(self) ],
        [ "/organizations/*/clients/*/keys", ActorKeysEndpoint.new(self) ],
        [ "/organizations/*/clients/*/keys/default", ActorDefaultKeyEndpoint.new(self) ],
        [ "/organizations/*/clients/*/keys/*", ActorKeyEndpoint.new(self) ],
        [ "/organizations/*/users/*/keys", OrganizationUserKeysEndpoint.new(self) ],
        [ "/organizations/*/users/*/keys/default", OrganizationUserDefaultKeyEndpoint.new(self) ],
        [ "/organizations/*/users/*/keys/*", OrganizationUserKeyEndpoint.new(self) ],
        [ "/organizations/*/controls", ControlsEndpoint.new(self) ],
        [ "/organizations/*/cookbooks", CookbooksEndpoint.new(self) ],
        [ "/organizations/*/cookbooks/*", CookbookEndpoint.new(self) ],
        [ "/organizations/*/cookbooks/*/*", CookbookVersionEndpoint.new(self) ],
        [ "/organizations/*/cookbook_artifacts", CookbookArtifactsEndpoint.new(self) ],
        [ "/organizations/*/cookbook_artifacts/*", CookbookArtifactEndpoint.new(self) ],
        [ "/organizations/*/cookbook_artifacts/*/*", CookbookArtifactIdentifierEndpoint.new(self) ],
        [ "/organizations/*/data", DataBagsEndpoint.new(self) ],
        [ "/organizations/*/data/*", DataBagEndpoint.new(self) ],
        [ "/organizations/*/data/*/*", DataBagItemEndpoint.new(self) ],
        [ "/organizations/*/environments", RestListEndpoint.new(self) ],
        [ "/organizations/*/environments/*", EnvironmentEndpoint.new(self) ],
        [ "/organizations/*/environments/*/cookbooks", EnvironmentCookbooksEndpoint.new(self) ],
        [ "/organizations/*/environments/*/cookbooks/*", EnvironmentCookbookEndpoint.new(self) ],
        [ "/organizations/*/environments/*/cookbook_versions", EnvironmentCookbookVersionsEndpoint.new(self) ],
        [ "/organizations/*/environments/*/nodes", EnvironmentNodesEndpoint.new(self) ],
        [ "/organizations/*/environments/*/recipes", EnvironmentRecipesEndpoint.new(self) ],
        [ "/organizations/*/environments/*/roles/*", EnvironmentRoleEndpoint.new(self) ],
        [ "/organizations/*/nodes", NodesEndpoint.new(self) ],
        [ "/organizations/*/nodes/*", NodeEndpoint.new(self) ],
        [ "/organizations/*/nodes/*/_identifiers", NodeIdentifiersEndpoint.new(self) ],
        [ "/organizations/*/policies", PoliciesEndpoint.new(self) ],
        [ "/organizations/*/policies/*", PolicyEndpoint.new(self) ],
        [ "/organizations/*/policies/*/revisions", PolicyRevisionsEndpoint.new(self) ],
        [ "/organizations/*/policies/*/revisions/*", PolicyRevisionEndpoint.new(self) ],
        [ "/organizations/*/policy_groups", PolicyGroupsEndpoint.new(self) ],
        [ "/organizations/*/policy_groups/*", PolicyGroupEndpoint.new(self) ],
        [ "/organizations/*/policy_groups/*/policies/*", PolicyGroupPolicyEndpoint.new(self) ],
        [ "/organizations/*/principals/*", PrincipalEndpoint.new(self) ],
        [ "/organizations/*/roles", RestListEndpoint.new(self) ],
        [ "/organizations/*/roles/*", RoleEndpoint.new(self) ],
        [ "/organizations/*/roles/*/environments", RoleEnvironmentsEndpoint.new(self) ],
        [ "/organizations/*/roles/*/environments/*", EnvironmentRoleEndpoint.new(self) ],
        [ "/organizations/*/sandboxes", SandboxesEndpoint.new(self) ],
        [ "/organizations/*/sandboxes/*", SandboxEndpoint.new(self) ],
        [ "/organizations/*/search", SearchesEndpoint.new(self) ],
        [ "/organizations/*/search/*", SearchEndpoint.new(self) ],
        [ "/version", VersionEndpoint.new(self) ],
        [ "/server_api_version", ServerAPIVersionEndpoint.new(self) ],

        # Internal
        [ "/organizations/*/file_store/**", FileStoreFileEndpoint.new(self) ],
      ]
    end

    def global_endpoint?(ep)
      GLOBAL_ENDPOINTS.any? do |g_ep|
        ep.start_with?(g_ep)
      end
    end

    def app
      return @app if @app
      router = RestRouter.new(endpoints)
      router.not_found = NotFoundEndpoint.new

      if options[:single_org]
        rest_base_prefix = [ "organizations", options[:single_org] ]
      else
        rest_base_prefix = []
      end
      @app = proc do |env|
        begin
          prefix = global_endpoint?(env["PATH_INFO"]) ? [] : rest_base_prefix

          request = RestRequest.new(env, prefix)
          if @on_request_proc
            @on_request_proc.call(request)
          end
          response = nil
          if @request_handler
            response = @request_handler.call(request)
          end
          unless response
            response = router.call(request)
          end
          if @on_response_proc
            @on_response_proc.call(request, response)
          end

          # Insert Server header
          response[1]["Server"] = "chef-zero"

          # Add CORS header
          response[1]["Access-Control-Allow-Origin"] = "*"

          # Puma expects the response to be an array (chunked responses). Since
          # we are statically generating data, we won't ever have said chunked
          # response, so fake it.
          response[-1] = Array(response[-1])

          response
        rescue
          if options[:log_level] == :debug
            STDERR.puts "Request Error: #{$!}"
            STDERR.puts $!.backtrace.join("\n")
          end
        end
      end
      @app
    end

    def dejsonize_children(hash)
      result = {}
      hash.each_pair do |key, value|
        result[key] = dejsonize(value)
      end
      result
    end

    def dejsonize(value)
      value.is_a?(Hash) ? FFI_Yajl::Encoder.encode(value, :pretty => true) : value
    end

    def get_file(directory, path)
      value = directory
      path.split("/").each do |part|
        value = value[part]
      end
      value
    end

    ## Disable unsecure ssl
    ## Ref: https://www.ruby-lang.org/en/news/2014/10/27/changing-default-settings-of-ext-openssl/
    def ssl_opts
      ssl_opts = OpenSSL::SSL::OP_ALL
      ssl_opts &= ~OpenSSL::SSL::OP_DONT_INSERT_EMPTY_FRAGMENTS if defined?(OpenSSL::SSL::OP_DONT_INSERT_EMPTY_FRAGMENTS)
      ssl_opts |= OpenSSL::SSL::OP_NO_COMPRESSION if defined?(OpenSSL::SSL::OP_NO_COMPRESSION)
      ssl_opts |= OpenSSL::SSL::OP_NO_SSLv2 if defined?(OpenSSL::SSL::OP_NO_SSLv2)
      ssl_opts |= OpenSSL::SSL::OP_NO_SSLv3 if defined?(OpenSSL::SSL::OP_NO_SSLv3)
      ssl_opts
    end
  end
end
