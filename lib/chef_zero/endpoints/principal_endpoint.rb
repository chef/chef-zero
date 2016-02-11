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
        # If /organizations/ORG/users/NAME exists, use this user (only org
        # members have precedence over clients).
        get_org_user_data(request, name) ||
          # If /organizations/ORG/clients/NAME exists, use the client.
          get_client_data(request, name) ||
          # If there is no client with that name, check for a user
          # (/users/NAME) and return that with org_member = false.
          get_user_data(request, name)
      end

      def get_org_user_data(request, name)
        user_path = request.rest_path.first(2) + [ 'users', name ]
        return if get_data(request, user_path, :nil).nil?

        # In single org. mode assume that we only support one user, "pivotal,"
        # and there is no user_keys data for that user; use the default
        # PUBLIC_KEY.
        public_key =
          if data_store.real_store.respond_to?(:single_org) && data_store.real_store.single_org
            PUBLIC_KEY
          else
            user_keys_json = get_data(request,
              [ 'user_keys', name, 'keys', DEFAULT_PUBLIC_KEY_NAME ],
              :data_store_exceptions
            )

            FFI_Yajl::Parser.parse(user_keys_json)['public_key']
          end

        { "type" => "user",
          "org_member" => true,
          "public_key" => public_key }
      end

      def get_client_data(request, name)
        base_path = request.rest_path.first(2)
        client_path = base_path + [ 'clients', name ]
        client_key_path = base_path + [ 'client_keys', name, 'keys', DEFAULT_PUBLIC_KEY_NAME ]

        get_actor_data(request, client_path, client_key_path,
                       "type" => "client", "org_member" => true)
      end

      def get_user_data(request, name)
        user_path = [ 'users', name ]
        user_key_path = [ 'user_keys', name, 'keys', DEFAULT_PUBLIC_KEY_NAME ]
        get_actor_data(request, user_path, user_key_path,
                       "type" => "user", "org_member" => false)
      end

      def get_actor_data(request, actor_path, actor_key_path, attrs={})
        return if get_data(request, actor_path, :nil).nil?
        actor_key_json = get_data(request, actor_key_path, :data_store_exceptions)
        public_key = FFI_Yajl::Parser.parse(actor_key_json)['public_key']
        attrs.merge("public_key" => public_key)
      end
    end
  end
end
