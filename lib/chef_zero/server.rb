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

require 'rubygems'
require 'thin'
require 'openssl'
require 'chef_zero'
require 'chef_zero/router'
require 'timeout'
require 'chef_zero/cookbook_data'

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
    def initialize(options = {})
      @options = options
      options[:host] ||= '127.0.0.1'
      options[:port] ||= 80
      options[:generate_real_keys] = true if !options.has_key?(:generate_real_keys)
      @server = Thin::Server.new(options[:host], options[:port], make_app)
      @generate_real_keys = options[:generate_real_keys]
      @data = {
        'clients' => {
          'chef-validator' => '{ "validator": true }',
          'chef-webui' => '{ "admin": true }'
        },
        'cookbooks' => {},
        'data' => {},
        'environments' => {
          '_default' => '{ "description": "The default Chef environment" }'
        },
        'file_store' => {},
        'nodes' => {},
        'roles' => {},
        'sandboxes' => {},
        'users' => {
          'admin' => '{ "admin": true }'
        }
      }
    end

    attr_reader :server
    attr_reader :data
    attr_reader :options
    attr_reader :generate_real_keys

    include ChefZero::Endpoints

    def url
      "http://#{options[:host]}:#{options[:port]}"
    end

    def start
      server.start
    end

    def start_background(timeout = 5)
      @thread = Thread.new do
        begin
          server.start
        rescue
          @server_error = $!
          Chef::Log.error("#{$!.message}\n#{$!.backtrace.join("\n")}")
        end
      end
      Timeout::timeout(timeout) do
        until server.running? || @server_error
          sleep(0.01)
        end
      end
    end

    def running?
      server.running?
    end

    def stop(timeout = 5)
      begin
        server.stop
        @thread.join(timeout)
        @thread = nil
      rescue
        Chef::Log.error("Server did not stop within #{timeout}s.  Killing.")
        @thread.kill if @thread
        @thread = nil
      end
    end

    def gen_key_pair
      if generate_real_keys
        private_key = OpenSSL::PKey::RSA.new(2048)
        public_key = private_key.public_key.to_s
        public_key.sub!(/^-----BEGIN RSA PUBLIC KEY-----/, '-----BEGIN PUBLIC KEY-----')
        public_key.sub!(/-----END RSA PUBLIC KEY-----(\s+)$/, '-----END PUBLIC KEY-----\1')
        [private_key.to_s, public_key]
      else
        [PRIVATE_KEY, PUBLIC_KEY]
      end
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
          dejsonize_children!(contents[data_type])
          data[data_type].merge!(contents[data_type])
        end
      end
      if contents['data']
        contents['data'].values.each do |data_bag|
          dejsonize_children!(data_bag)
        end
        data['data'].merge!(contents['data'])
      end
      if contents['cookbooks']
        contents['cookbooks'].each_pair do |name_version, cookbook|
          if name_version =~ /(.+)-(\d+\.\d+\.\d+)$/
            cookbook_data = CookbookData.to_hash(cookbook, $1, $2)
          else
            cookbook_data = CookbookData.to_hash(cookbook, name_version)
          end
          raise "No version specified" if !cookbook_data[:version]
          data['cookbooks'][cookbook_data[:cookbook_name]] = {} if !data['cookbooks'][cookbook_data[:cookbook_name]]
          data['cookbooks'][cookbook_data[:cookbook_name]][cookbook_data[:version]] = JSON.pretty_generate(cookbook_data)
          cookbook_data.values.each do |files|
            next unless files.is_a? Array
            files.each do |file|
              data['file_store'][file[:checksum]] = get_file(cookbook, file[:path])
            end
          end
        end
      end
    end

    private

    def make_app
      router = Router.new([
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

        [ '/file_store/*', FileStoreFileEndpoint.new(self) ],
      ])
      router.not_found = NotFoundEndpoint.new
      router
    end

    def dejsonize_children!(hash)
      hash.each_pair do |key, value|
        hash[key] = JSON.pretty_generate(value) if value.is_a?(Hash)
      end
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
