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

      def data_path(request)
        root = request.rest_path[2] == "clients" ? "client_keys" : "user_keys"
        [root, *request.rest_path.last(3) ]
      end
    end
  end
end
