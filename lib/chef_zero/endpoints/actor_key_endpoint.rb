require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /users/USER/keys/NAME
    # /organizations/ORG/clients/CLIENT/keys/NAME
    class ActorKeyEndpoint < RestBase
      def get(request)
        path = [ "user_keys", *request.rest_path[1..-1] ]
        already_json_response(200, get_data(request, path))
      end

      def delete(request)
        path = [ "user_keys", *request.rest_path[1..-1] ]

        data = get_data(request, path)
        delete_data(request, path)

        already_json_response(200, data)
      end

      def put(request)
        path = [ "user_keys", *request.rest_path[1..-1] ]

        # We grab the old data to trigger a 404 if it doesn't exist
        get_data(request, path)

        set_data(request, path, request.body)
      end
    end
  end
end
