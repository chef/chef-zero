require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # ActorKeyEndpoint
    #
    # This class handles DELETE/GET/PUT requests for all client/user keys
    # **except** default public keys, i.e. requests with identity key
    # "default". Those are handled by ActorDefaultKeyEndpoint. See that class
    # for more information.
    #
    # /users/USER/keys/NAME
    # /organizations/ORG/clients/CLIENT/keys/NAME
    class ActorKeyEndpoint < RestBase
      def get(request)
        validate_actor!(request)
        key_path = data_path(request)
        already_json_response(200, get_data(request, key_path))
      end

      def delete(request)
        validate_actor!(request) # 404 if actor doesn't exist

        key_path = data_path(request)
        data = get_data(request, key_path)
        delete_data(request, key_path)

        already_json_response(200, data)
      end

      def put(request)
        validate_actor!(request) # 404 if actor doesn't exist
        set_data(request, data_path(request), request.body)
      end

      private

      # Returns the keys data store path, which is the same as
      # `request.rest_path` except with "client_keys" instead of "clients" or
      # "user_keys" instead of "users."
      def data_path(request)
        request.rest_path.dup.tap do |path|
          if client?(request)
            path[2] = "client_keys"
          else
            path[0] = "user_keys"
          end
        end
      end

      # Raises RestErrorResponse (404) if actor doesn't exist
      def validate_actor!(request)
        actor_path = request.rest_path[ client?(request) ? 0..3 : 0..1 ]
        get_data(request, actor_path)
      end

      def client?(request)
        request.rest_path[2] == "clients"
      end
    end
  end
end
