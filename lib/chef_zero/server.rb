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

require 'openssl'
require 'open-uri'
require 'rubygems'
require 'timeout'
require 'stringio'

require 'rack'
require 'webrick'

require 'chef_zero'
require 'chef_zero/cookbook_data'
require 'chef_zero/rest_router'
require 'chef_zero/data_store/memory_store_v2'
require 'chef_zero/data_store/v1_to_v2_adapter'
require 'chef_zero/data_store/default_facade'
require 'chef_zero/version'

require 'chef_zero/endpoints/rest_list_endpoint'
require 'chef_zero/endpoints/authenticate_user_endpoint'
require 'chef_zero/endpoints/acls_endpoint'
require 'chef_zero/endpoints/acl_endpoint'
require 'chef_zero/endpoints/actors_endpoint'
require 'chef_zero/endpoints/actor_endpoint'
require 'chef_zero/endpoints/cookbooks_endpoint'
require 'chef_zero/endpoints/cookbook_endpoint'
require 'chef_zero/endpoints/cookbook_version_endpoint'
require 'chef_zero/endpoints/containers_endpoint'
require 'chef_zero/endpoints/container_endpoint'
require 'chef_zero/endpoints/data_bags_endpoint'
require 'chef_zero/endpoints/data_bag_endpoint'
require 'chef_zero/endpoints/data_bag_item_endpoint'
require 'chef_zero/endpoints/groups_endpoint'
require 'chef_zero/endpoints/group_endpoint'
require 'chef_zero/endpoints/environment_endpoint'
require 'chef_zero/endpoints/environment_cookbooks_endpoint'
require 'chef_zero/endpoints/environment_cookbook_endpoint'
require 'chef_zero/endpoints/environment_cookbook_versions_endpoint'
require 'chef_zero/endpoints/environment_nodes_endpoint'
require 'chef_zero/endpoints/environment_recipes_endpoint'
require 'chef_zero/endpoints/environment_role_endpoint'
require 'chef_zero/endpoints/node_endpoint'
require 'chef_zero/endpoints/organizations_endpoint'
require 'chef_zero/endpoints/organization_endpoint'
require 'chef_zero/endpoints/organization_validator_key_endpoint'
require 'chef_zero/endpoints/principal_endpoint'
require 'chef_zero/endpoints/role_endpoint'
require 'chef_zero/endpoints/role_environments_endpoint'
require 'chef_zero/endpoints/sandboxes_endpoint'
require 'chef_zero/endpoints/sandbox_endpoint'
require 'chef_zero/endpoints/searches_endpoint'
require 'chef_zero/endpoints/search_endpoint'
require 'chef_zero/endpoints/file_store_file_endpoint'
require 'chef_zero/endpoints/not_found_endpoint'

module ChefZero
  class Server
    DEFAULT_OPTIONS = {
      :host => '127.0.0.1',
      :port => 8889,
      :log_level => :info,
      :generate_real_keys => true,
      :single_org => 'chef'
    }.freeze

    def initialize(options = {})
      @options = DEFAULT_OPTIONS.merge(options)
      @options.freeze

      ChefZero::Log.level = @options[:log_level].to_sym
    end

    # @return [Hash]
    attr_reader :options

    # @return [Integer]
    def port
      if @port
        @port
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
      @url ||= if @options[:host].include?(':')
                 URI("http://[#{@options[:host]}]:#{port}").to_s
               else
                 URI("http://#{@options[:host]}:#{port}").to_s
               end
    end

    #
    # The data store for this server (default is in-memory).
    #
    # @return [ChefZero::DataStore]
    #
    def data_store
      @data_store ||= begin
        result = @options[:data_store] || DataStore::DefaultFacade.new(DataStore::MemoryStoreV2.new, options[:single_org])
        if options[:single_org]
          if result.respond_to?(:interface_version) && result.interface_version >= 2 && result.interface_version < 3
            result.create_dir([ 'organizations' ], options[:single_org])
          else
            result = ChefZero::DataStore::V1ToV2Adapter.new(result, options[:single_org])
            result = ChefZero::DataStore::DefaultFacade.new(result, options[:single_org])
          end
        else
          if !(result.respond_to?(:interface_version) && result.interface_version >= 2 && result.interface_version < 3)
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
        output.puts <<-EOH.gsub(/^ {10}/, '')
          >> Starting Chef Zero (v#{ChefZero::VERSION})...
        EOH
      end

      thread = start_background

      if publish
        output = publish.respond_to?(:puts) ? publish : STDOUT
        output.puts <<-EOH.gsub(/^ {10}/, '')
          >> WEBrick (v#{WEBrick::VERSION}) on Rack (v#{Rack.release}) is listening at #{url}
          >> Press CTRL+C to stop

        EOH
      end

      %w[INT TERM].each do |signal|
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
    def start_background(wait = 5)
      @server = WEBrick::HTTPServer.new(
        :DoNotListen => true,
        :AccessLog   => [],
        :Logger      => WEBrick::Log.new(StringIO.new, 7),
        :StartCallback => proc {
          @running = true
        }
      )
      @server.mount('/', Rack::Handler::WEBrick, app)

      # Pick a port
      if options[:port].respond_to?(:each)
        options[:port].each do |port|
          begin
            @server.listen(options[:host], port)
            @port = port
            break
          rescue Errno::EADDRINUSE
            ChefZero::Log.info("Port #{port} in use: #{$!}")
          end
        end
        if !@port
          raise Errno::EADDRINUSE, "No port in :port range #{options[:port]} is available"
        end
      else
        @server.listen(options[:host], options[:port])
        @port = options[:port]
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
      while !@running && @thread.alive?
        sleep(0.01)
      end

      @thread
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
        @server.shutdown
        @thread.join(wait)
      end
    rescue Timeout::Error
      if @thread
        ChefZero::Log.error("Chef Zero did not stop within #{wait} seconds! Killing...")
        @thread.kill
      end
    ensure
      @server = nil
      @thread = nil
    end

    def gen_key_pair
      if generate_real_keys?
        private_key = OpenSSL::PKey::RSA.new(2048)
        public_key = private_key.public_key.to_s
        public_key.sub!(/^-----BEGIN RSA PUBLIC KEY-----/, '-----BEGIN PUBLIC KEY-----')
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
    def load_data(contents, org_name = 'chef')
      %w(clients environments nodes roles users).each do |data_type|
        if contents[data_type]
          dejsonize_children(contents[data_type]).each_pair do |name, data|
            data_store.set(['organizations', org_name, data_type, name], data, :create)
          end
        end
      end
      if contents['data']
        contents['data'].each_pair do |key, data_bag|
          data_store.create_dir(['organizations', org_name, 'data'], key, :recursive)
          dejsonize_children(data_bag).each do |item_name, item|
            data_store.set(['organizations', org_name, 'data', key, item_name], item, :create)
          end
        end
      end
      if contents['cookbooks']
        contents['cookbooks'].each_pair do |name_version, cookbook|
          if name_version =~ /(.+)-(\d+\.\d+\.\d+)$/
            cookbook_data = CookbookData.to_hash(cookbook, $1, $2)
          else
            cookbook_data = CookbookData.to_hash(cookbook, name_version)
          end
          raise "No version specified" if !cookbook_data[:version]
          data_store.create_dir(['organizations', org_name, 'cookbooks'], cookbook_data[:cookbook_name], :recursive)
          data_store.set(['organizations', org_name, 'cookbooks', cookbook_data[:cookbook_name], cookbook_data[:version]], JSON.pretty_generate(cookbook_data), :create)
          cookbook_data.values.each do |files|
            next unless files.is_a? Array
            files.each do |file|
              data_store.set(['organizations', org_name, 'file_store', 'checksums', file[:checksum]], get_file(cookbook, file[:path]), :create)
            end
          end
        end
      end
    end

    def clear_data
      data_store.clear
      if options[:single_org]
        data_store.create_dir([ 'organizations' ], options[:single_org])
      end
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

    def open_source_endpoints
      result = if options[:single_org]
        # OSC-only
        [
          [ "/organizations/*/users", ActorsEndpoint.new(self) ],
          [ "/organizations/*/users/*", ActorEndpoint.new(self) ]
        ]
      else
        [
      #   # EC-only
      #   [ "/organizations/*/users", EcUsersEndpoint.new(self) ],
      #   [ "/organizations/*/users/*", EcUserEndpoint.new(self) ],
          [ "/users", ActorsEndpoint.new(self) ],
          [ "/users/*", ActorEndpoint.new(self) ],
          [ "/users/_acl", AclsEndpoint.new(self) ],
          [ "/users/_acl/*", AclEndpoint.new(self) ]
      #   [ "/verify_password", VerifyPasswordEndpoint.new(self) ],
      #   [ "/authenticate_user", AuthenticateUserEndpoint.new(self) ],
      #   [ "/system_recovery", SystemRecoveryEndpoint.new(self) ],
        ]
      end
      result +
      [
        # Both
        [ "/organizations", OrganizationsEndpoint.new(self) ],
        [ "/organizations/*", OrganizationEndpoint.new(self) ],
        [ "/organizations/*/_validator_key", OrganizationValidatorKeyEndpoint.new(self) ],
        # [ "/organizations/*/members", RestObjectEndpoint.new(self) ],
        # [ "/organizations/*/association_requests", AssociationRequestsEndpoint.new(self) ],
        # [ "/organizations/*/association_requests/count", AssociationRequestsCountEndpoint.new(self) ],
        # [ "/organizations/*/association_requests/*", AssociationRequestEndpoint.new(self) ],
        [ "/organizations/*/containers", ContainersEndpoint.new(self) ],
        [ "/organizations/*/containers/*", ContainerEndpoint.new(self) ],
        [ "/organizations/*/groups", GroupsEndpoint.new(self) ],
        [ "/organizations/*/groups/*", GroupEndpoint.new(self) ],
        # [ "/users/*/organizations", UserOrganizationsEndpoint.new(self) ],
        # [ "/users/*/association_requests", UserAssocationRequestsEndpoint.new(self) ],
        # [ "/users/*/association_requests/*", UserAssociationRequestEndpoint.new(self) ],
        [ "/organizations/*/organization/_acl", AclsEndpoint.new(self) ],
        [ "/organizations/*/*/*/_acl", AclsEndpoint.new(self) ],
        [ "/organizations/*/organization/_acl/*", AclEndpoint.new(self) ],
        [ "/organizations/*/*/*/_acl/*", AclEndpoint.new(self) ],

        [ "/organizations/*/authenticate_user", AuthenticateUserEndpoint.new(self) ],
        [ "/organizations/*/clients", ActorsEndpoint.new(self) ],
        [ "/organizations/*/clients/*", ActorEndpoint.new(self) ],
        [ "/organizations/*/cookbooks", CookbooksEndpoint.new(self) ],
        [ "/organizations/*/cookbooks/*", CookbookEndpoint.new(self) ],
        [ "/organizations/*/cookbooks/*/*", CookbookVersionEndpoint.new(self) ],
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
        [ "/organizations/*/nodes", RestListEndpoint.new(self) ],
        [ "/organizations/*/nodes/*", NodeEndpoint.new(self) ],
        [ "/organizations/*/principals/*", PrincipalEndpoint.new(self) ],
        [ "/organizations/*/roles", RestListEndpoint.new(self) ],
        [ "/organizations/*/roles/*", RoleEndpoint.new(self) ],
        [ "/organizations/*/roles/*/environments", RoleEnvironmentsEndpoint.new(self) ],
        [ "/organizations/*/roles/*/environments/*", EnvironmentRoleEndpoint.new(self) ],
        [ "/organizations/*/sandboxes", SandboxesEndpoint.new(self) ],
        [ "/organizations/*/sandboxes/*", SandboxEndpoint.new(self) ],
        [ "/organizations/*/search", SearchesEndpoint.new(self) ],
        [ "/organizations/*/search/*", SearchEndpoint.new(self) ],

        # Internal
        [ "/organizations/*/file_store/**", FileStoreFileEndpoint.new(self) ],
      ]
    end

    def app
      router = RestRouter.new(open_source_endpoints)
      router.not_found = NotFoundEndpoint.new

      if options[:single_org]
        rest_base_prefix = [ 'organizations', options[:single_org] ]
      else
        rest_base_prefix = []
      end
      return proc do |env|
        begin
          request = RestRequest.new(env, rest_base_prefix)
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
          response[1]['Server'] = 'chef-zero'

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
    end

    def dejsonize_children(hash)
      result = {}
      hash.each_pair do |key, value|
        result[key] = value.is_a?(Hash) ? JSON.pretty_generate(value) : value
      end
      result
    end

    def get_file(directory, path)
      value = directory
      path.split('/').each do |part|
        value = value[part]
      end
      value
    end
  end
end
