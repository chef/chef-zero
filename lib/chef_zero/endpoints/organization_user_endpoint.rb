require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/users/NAME
    class OrganizationUserEndpoint < RestBase
      DEFAULT_PUBLIC_KEY_NAME = "default"

      def get(request)
        username = request.rest_path[3]
        get_data(request) # 404 if user is not in org

        user = get_data(request, [ 'users', username ])
        user = FFI_Yajl::Parser.parse(user, :create_additions => false)

        user["public_key"] = get_user_default_public_key(request, username)

        json_response(200, ChefData::DataNormalizer.normalize_user(user, username, ['username'], server.options[:osc_compat], request.method))
      end

      def delete(request)
        user = get_data(request)
        delete_data(request)
        user = FFI_Yajl::Parser.parse(user, :create_additions => false)
        json_response(200, ChefData::DataNormalizer.normalize_user(user, request.rest_path[3], ['username'], server.options[:osc_compat]))
      end

      # Note: post to a named org user is not permitted, allow invalid method handling (405)

      private
      # Returns the user's default public_key from user_keys store
      def get_user_default_public_key(request, username)
        path = [ "user_keys", username, "keys", DEFAULT_PUBLIC_KEY_NAME ]
        key_json = get_data(request, path, :nil)
        return unless key_json

        key_data = FFI_Yajl::Parser.parse(key_json, create_additions: false)
        key_data && key_data["public_key"]
      end
    end
  end
end
