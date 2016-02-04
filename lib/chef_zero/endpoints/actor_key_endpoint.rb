require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /users/USER/keys/NAME
    # /organizations/ORG/clients/CLIENT/keys/NAME
    class ActorKeyEndpoint < RestBase
      def get(request)
        path = data_path(request)
        already_json_response(200, get_data(request, path))
      end

      def delete(request)
        path = data_path(request)

        data = get_data(request, path)
        delete_data(request, path)

        already_json_response(200, data)
      end

      def put(request)
        # We grab the old data to trigger a 404 if it doesn't exist
        get_data(request, data_path(request))

        set_data(request, path, request.body)
      end

      private

      # Returns the keys data store path, which is the same as
      # `request.rest_path` except with "user_keys" instead of "users" or
      # "client_keys" instead of "clients."
      def data_path(request)
        request.rest_path.dup.tap do |path|
          if request.rest_path[2] == "clients"
            path[2] = "client_keys"
          else
            path[0] = "user_keys"
          end
        end
      end
    end
  end
end
