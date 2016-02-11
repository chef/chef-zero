require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /users/USER/keys/NAME
    # /organizations/ORG/clients/CLIENT/keys/NAME
    class ActorKeyEndpoint < RestBase
      DEFAULT_PUBLIC_KEY_NAME = "default".freeze

      def get(request)
        # Try to get the actor so a 404 is returned if it doesn't exist
        actor_json = get_actor_json(request)

        if request.rest_path[-1] == DEFAULT_PUBLIC_KEY_NAME
          actor_data = FFI_Yajl::Parser.parse(actor_json, create_additions: false)
          default_public_key = default_public_key_from_actor(actor_data)
          return json_response(200, default_public_key)
        end

        key_path = data_path(request)
        already_json_response(200, get_data(request, key_path))
      end

      def delete(request)
        # Try to get the actor so a 404 is returned if it doesn't exist
        actor_json = get_actor_json(request)

        if request.rest_path[-1] == DEFAULT_PUBLIC_KEY_NAME
          actor_data = FFI_Yajl::Parser.parse(actor_json, create_additions: false)
          default_public_key = delete_actor_default_public_key!(request, actor_data)
          return json_response(200, default_public_key)
        end

        key_path = data_path(request)

        data = get_data(request, key_path)
        delete_data(request, key_path)

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
          if client?(request)
            path[2] = "client_keys"
          else
            path[0] = "user_keys"
          end
        end
      end

      def default_public_key_from_actor(actor_data)
        { "name" => DEFAULT_PUBLIC_KEY_NAME,
          "public_key" => actor_data["public_key"],
          "expiration_date" => "infinity" }
      end

      def delete_actor_default_public_key!(request, actor_data)
        new_actor_data = actor_data.merge("public_key" => nil)

        set_data(
          request,
          actor_path(request),
          FFI_Yajl::Encoder.encode(new_actor_data, pretty: true)
        )

        default_public_key_from_actor(actor_data)
      end

      def get_actor_json(request)
        get_data(request, actor_path(request))
      end

      def client?(request)
        request.rest_path[2] == "clients"
      end

      def actor_path(request)
        return request.rest_path[0..3] if client?(request)
        request.rest_path[0..1]
      end
    end
  end
end
