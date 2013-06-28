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
require 'puma'
require 'rubygems'
require 'timeout'

require 'chef_zero'
require 'chef_zero/cookbook_data'
require 'chef_zero/rest_router'
require 'chef_zero/data_store/memory_store'
require 'chef_zero/version'

require 'chef_zero/endpoints/authenticate_user_endpoint'
require 'chef_zero/endpoints/actors_endpoint'
require 'chef_zero/endpoints/actor_endpoint'
require 'chef_zero/endpoints/cookbooks_endpoint'
require 'chef_zero/endpoints/cookbook_endpoint'
require 'chef_zero/endpoints/cookbook_version_endpoint'
require 'chef_zero/endpoints/data_bags_endpoint'
require 'chef_zero/endpoints/data_bag_endpoint'
require 'chef_zero/endpoints/data_bag_item_endpoint'
require 'chef_zero/endpoints/rest_list_endpoint'
require 'chef_zero/endpoints/environment_endpoint'
require 'chef_zero/endpoints/environment_cookbooks_endpoint'
require 'chef_zero/endpoints/environment_cookbook_endpoint'
require 'chef_zero/endpoints/environment_cookbook_versions_endpoint'
require 'chef_zero/endpoints/environment_nodes_endpoint'
require 'chef_zero/endpoints/environment_recipes_endpoint'
require 'chef_zero/endpoints/environment_role_endpoint'
require 'chef_zero/endpoints/node_endpoint'
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
      :socket => nil,
      :log_level => :info,
      :generate_real_keys => true
    }.freeze

    def initialize(options = {})
      options = DEFAULT_OPTIONS.merge(options)
      @url = "http://#{options[:host]}:#{options[:port]}"
      @generate_real_keys = options[:generate_real_keys]

      ChefZero::Log.level = options[:log_level].to_sym

      @server = Puma::Server.new(make_app, Puma::Events.new(STDERR, STDOUT))
      if options[:socket]
        @server.add_unix_listener(options[:socket])
      else
        @server.add_tcp_listener(options[:host], options[:port])
      end


      @data_store = options[:data_store] || DataStore::MemoryStore.new
    end

    attr_reader :server
    attr_reader :data_store
    attr_reader :url

    include ChefZero::Endpoints

    def start(options = {})
      if options[:publish]
        puts ">> Starting Chef Zero (v#{ChefZero::VERSION})..."
        puts ">> Puma (v#{Puma::Const::PUMA_VERSION}) is listening at #{url}"
        puts ">> Press CTRL+C to stop"
      end

      begin
        thread = server.run.join
      rescue Object, Interrupt
        puts "\n>> Stopping Puma..."
        server.stop(true) if running?
      end
    end

    def start_background(wait = 5)
      @thread = Thread.new {
        begin
          start
        rescue
          @server_error = $!
          ChefZero::Log.error("#{$!.message}\n#{$!.backtrace.join("\n")}")
        end
      }

      # Wait x seconds to make sure the server actually started
      Timeout::timeout(wait) {
        sleep(0.01) until running? || @server_error
        raise @server_error if @server_error
      }

      # Give the user the thread, just in case they want it
      @thread
    end

    def running?
      !!server.running
    end

    def stop(wait = 5)
      if @thread
        @thread.join(wait)
      else
        server.stop(true)
      end
    rescue
      ChefZero::Log.error "Server did not stop within #{wait} seconds. Killing..."
      @thread.kill if @thread
    ensure
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
    def load_data(contents)
      %w(clients environments nodes roles users).each do |data_type|
        if contents[data_type]
          dejsonize_children(contents[data_type]).each_pair do |name, data|
            data_store.set([data_type, name], data, :create)
          end
        end
      end
      if contents['data']
        contents['data'].each_pair do |key, data_bag|
          data_store.create_dir(['data'], key, :recursive)
          dejsonize_children(data_bag).each do |item_name, item|
            data_store.set(['data', key, item_name], item, :create)
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
          data_store.create_dir(['cookbooks'], cookbook_data[:cookbook_name], :recursive)
          data_store.set(['cookbooks', cookbook_data[:cookbook_name], cookbook_data[:version]], JSON.pretty_generate(cookbook_data), :create)
          cookbook_data.values.each do |files|
            next unless files.is_a? Array
            files.each do |file|
              data_store.set(['file_store', 'checksums', file[:checksum]], get_file(cookbook, file[:path]), :create)
            end
          end
        end
      end
    end

    def clear_data
      @data_store.clear
    end

    def request_handler(&block)
      @request_handler = block
    end

    private

    def make_app
      router = RestRouter.new([
        [ '/authenticate_user', AuthenticateUserEndpoint.new(self) ],
        [ '/clients', ActorsEndpoint.new(self) ],
        [ '/clients/*', ActorEndpoint.new(self) ],
        [ '/cookbooks', CookbooksEndpoint.new(self) ],
        [ '/cookbooks/*', CookbookEndpoint.new(self) ],
        [ '/cookbooks/*/*', CookbookVersionEndpoint.new(self) ],
        [ '/data', DataBagsEndpoint.new(self) ],
        [ '/data/*', DataBagEndpoint.new(self) ],
        [ '/data/*/*', DataBagItemEndpoint.new(self) ],
        [ '/environments', RestListEndpoint.new(self) ],
        [ '/environments/*', EnvironmentEndpoint.new(self) ],
        [ '/environments/*/cookbooks', EnvironmentCookbooksEndpoint.new(self) ],
        [ '/environments/*/cookbooks/*', EnvironmentCookbookEndpoint.new(self) ],
        [ '/environments/*/cookbook_versions', EnvironmentCookbookVersionsEndpoint.new(self) ],
        [ '/environments/*/nodes', EnvironmentNodesEndpoint.new(self) ],
        [ '/environments/*/recipes', EnvironmentRecipesEndpoint.new(self) ],
        [ '/environments/*/roles/*', EnvironmentRoleEndpoint.new(self) ],
        [ '/nodes', RestListEndpoint.new(self) ],
        [ '/nodes/*', NodeEndpoint.new(self) ],
        [ '/principals/*', PrincipalEndpoint.new(self) ],
        [ '/roles', RestListEndpoint.new(self) ],
        [ '/roles/*', RoleEndpoint.new(self) ],
        [ '/roles/*/environments', RoleEnvironmentsEndpoint.new(self) ],
        [ '/roles/*/environments/*', EnvironmentRoleEndpoint.new(self) ],
        [ '/sandboxes', SandboxesEndpoint.new(self) ],
        [ '/sandboxes/*', SandboxEndpoint.new(self) ],
        [ '/search', SearchesEndpoint.new(self) ],
        [ '/search/*', SearchEndpoint.new(self) ],
        [ '/users', ActorsEndpoint.new(self) ],
        [ '/users/*', ActorEndpoint.new(self) ],

        [ '/file_store/**', FileStoreFileEndpoint.new(self) ],
      ])
      router.not_found = NotFoundEndpoint.new

      return proc do |env|
        request = RestRequest.new(env)
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
      end
    end

    def dejsonize_children(hash)
      result = {}
      hash.each_pair do |key, value|
        result[key] = value.is_a?(Hash)  ? JSON.pretty_generate(value) : value
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

    def generate_real_keys?
      !!@generate_real_keys
    end
  end
end
