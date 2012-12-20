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
require 'webrick'
require 'rack'
require 'openssl'
require 'chef_zero'
require 'chef_zero/router'

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
  class Server < Rack::Server
    def initialize(options)
      options[:host] ||= "localhost" # TODO 0.0.0.0?
      options[:port] ||= 80
      options[:generate_real_keys] = true if !options.has_key?(:generate_real_keys)
      super(options)
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

    attr_reader :data
    attr_reader :generate_real_keys

    include ChefZero::Endpoints

    def app
      @app ||= begin
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
  end
end
