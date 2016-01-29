require 'ffi_yajl'
require 'chef_zero'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /principals/NAME
    class PrincipalEndpoint < RestBase
      DEFAULT_PUBLIC_KEY_NAME = "default"

      def get(request)
        name = request.rest_path[-1]
        data = get_principal_data(request, name)

        if data
          return json_response(200, data.merge(
            'authz_id' => '0'*32,
            'name' => name,
          ))
        end

        error(404, 'Principal not found')
      end

      private

      def get_principal_data(request, name)
        # If /organizations/ORG/users/NAME exists, use this user (only org members have precedence over clients).        hey are an org member.
        get_org_users_data(request, name) ||
          # If /organizations/ORG/clients/NAME exists, use the client.
          get_clients_data(request, name) ||
          # If there is no client with that name, check for a user (/users/NAME) and return that with
          # org_member = false.
          get_users_data(request, name)
      end

      def get_org_users_data(request, name)
        path = [ *request.rest_path[0..1], 'users', name ]
        return if get_data(request, path, :nil).nil?

        user_keys_json = get_data(request,
          [ 'user_keys', name, 'keys', DEFAULT_PUBLIC_KEY_NAME ],
          :data_store_exceptions
        )

        public_key = FFI_Yajl::Parser.parse(user_keys_json)['public_key']

        { "type" => "user",
          "org_member" => true,
          "public_key" => public_key
        }
      end

      def get_clients_data(request, name)
        path = [ *request.rest_path[0..1], 'clients', name ]
        json = get_data(request, path, :nil)
        return if json.nil?

        public_key = FFI_Yajl::Parser.parse(json)['public_key']

        { "type" => "client",
          "org_member" => true,
          "public_key" => public_key || PUBLIC_KEY
        }
      end

      def get_users_data(request, name)
        path = [ 'users', name ]
        return if get_data(request, path, :nil).nil?

        user_keys_json = get_data(request,
          [ 'user_keys', name, 'keys', DEFAULT_PUBLIC_KEY_NAME ],
          :data_store_exceptions
        )

        public_key = FFI_Yajl::Parser.parse(user_keys_json)['public_key']

        { "type" => "user",
          "org_member" => false,
          "public_key" => public_key
        }
      end
    end
  end
end
