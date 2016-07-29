require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # ActorDefaultKeyEndpoint
    #
    # This class handles DELETE/GET/PUT requests for client/user default public
    # keys, i.e. requests with identity key "default". All others are handled
    # by ActorKeyEndpoint.
    #
    # Default public keys are stored with the actor (client or user) instead of
    # under user/client_keys. Handling those in a separate endpoint offloads
    # the branching logic onto the router rather than branching in every
    # endpoint method (`if request.rest_path[-1] == "default" ...`).
    #
    # /users/USER/keys/default
    # /organizations/ORG/clients/CLIENT/keys/default
    class ActorDefaultKeyEndpoint < RestBase
      DEFAULT_PUBLIC_KEY_NAME = "default".freeze

      def get(request)
        # 404 if actor doesn't exist
        actor_data = get_actor_data(request)
        key_data = default_public_key_from_actor(actor_data)

        # 404 if the actor doesn't have a default key
        if key_data["public_key"].nil?
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
        end

        json_response(200, default_public_key_from_actor(actor_data))
      end

      def delete(request)
        path = actor_path(request)
        actor_data = get_actor_data(request) # 404 if actor doesn't exist

        default_public_key = delete_actor_default_public_key!(request, path, actor_data)
        json_response(200, default_public_key)
      end

      def put(request)
        # 404 if actor doesn't exist
        actor_data = get_actor_data(request)

        new_public_key = parse_json(request.body)["public_key"]
        actor_data["public_key"] = new_public_key

        set_data(request, actor_path(request), to_json(actor_data))
      end

      private

      def actor_path(request)
        return request.rest_path[0..3] if request.rest_path[2] == "clients"
        request.rest_path[0..1]
      end

      def get_actor_data(request)
        path = actor_path(request)
        parse_json(get_data(request, path))
      end

      def default_public_key_from_actor(actor_data)
        { "name" => DEFAULT_PUBLIC_KEY_NAME,
          "public_key" => actor_data["public_key"],
          "expiration_date" => "infinity" }
      end

      def delete_actor_default_public_key!(request, path, actor_data)
        new_actor_data = actor_data.merge("public_key" => nil)
        set_data(request, path, to_json(new_actor_data))
        default_public_key_from_actor(actor_data)
      end
    end
  end
end
