require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /users/USER/keys
    # /organizations/ORG/clients/CLIENT/keys
    class ActorKeysEndpoint < RestBase
      DEFAULT_PUBLIC_KEY_NAME = "default"
      DATE_FORMAT = "%FT%TZ" # e.g. 2015-12-24T21:00:00Z

      def get(request, alt_uri_root = nil)
        path = data_path(request)

        # Get actor or 404 if it doesn't exist
        actor_json = get_data(request, actor_path(request))

        key_names = list_data_or_else(request, path, [])
        key_names.unshift(DEFAULT_PUBLIC_KEY_NAME) if actor_has_default_public_key?(actor_json)

        result = key_names.map do |key_name|
          list_key(request, [ *path, key_name ], alt_uri_root)
        end

        json_response(200, result)
      end

      def post(request)
        request_body = parse_json(request.body)

        # Try loading the client or user so a 404 is returned if it doesn't exist
        actor_json = get_data(request, actor_path(request))

        generate_keys = request_body["public_key"].nil?

        if generate_keys
          private_key, public_key = server.gen_key_pair
        else
          public_key = request_body["public_key"]
        end

        key_name = request_body["name"]

        if key_name == DEFAULT_PUBLIC_KEY_NAME
          store_actor_default_public_key!(request, actor_json, public_key)
        else
          store_actor_public_key!(request, key_name, public_key, request_body["expiration_date"])
        end

        response_body = { "uri" => key_uri(request, key_name) }
        response_body["private_key"] = private_key if generate_keys

        json_response(201, response_body,
                      headers: { "Location" => response_body["uri"] })
      end

      private

      def store_actor_public_key!(request, name, public_key, expiration_date)
        data = to_json(
          "name" => name,
          "public_key" => public_key,
          "expiration_date" => expiration_date
        )

        create_data(request, data_path(request), name, data, :create_dir)
      end

      def store_actor_default_public_key!(request, actor_json, public_key)
        actor_data = parse_json(actor_json)

        if actor_data["public_key"]
          raise RestErrorResponse.new(409, "Object already exists: #{key_uri(request, DEFAULT_PUBLIC_KEY_NAME)}")
        end

        actor_data["public_key"] = public_key
        set_data(request, actor_path(request), to_json(actor_data))
      end

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

      def list_key(request, data_path, alt_uri_root = nil)
        key_name, expiration_date =
          if data_path[-1] == DEFAULT_PUBLIC_KEY_NAME
            [ DEFAULT_PUBLIC_KEY_NAME, "infinity" ]
          else
            parse_json(get_data(request, data_path))
              .values_at("name", "expiration_date")
          end

        expired = expiration_date != "infinity" &&
          DateTime.now > DateTime.strptime(expiration_date, DATE_FORMAT)

        { "name" => key_name,
          "uri" => key_uri(request, key_name, alt_uri_root),
          "expired" => expired }
      end

      def client?(request)
        request.rest_path[2] == "clients"
      end

      def key_uri(request, key_name, alt_uri_root = nil)
        uri_root = alt_uri_root.nil? ? request.rest_path : alt_uri_root
        build_uri(request.base_uri, [ *uri_root, key_name ])
      end

      def actor_path(request)
        return request.rest_path[0..3] if client?(request)
        request.rest_path[0..1]
      end

      def actor_has_default_public_key?(actor_json)
        !!parse_json(actor_json)["public_key"]
      end
    end
  end
end
