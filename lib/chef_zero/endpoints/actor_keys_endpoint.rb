require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /users/USER/keys
    # /organizations/ORG/clients/CLIENT/keys
    class ActorKeysEndpoint < RestBase
      DATE_FORMAT = "%FT%TZ" # e.g. 2015-12-24T21:00:00Z

      def get(request)
        path = data_path(request)

        result = list_data(request, path).map do |key_name|
          list_key(request, [ *path, key_name ])
        end

        json_response(200, result)
      end

      def post(request)
        request_body = FFI_Yajl::Parser.parse(request.body)

        validate_client_or_user!(request)

        generate_keys = request_body["public_key"].nil?

        if generate_keys
          private_key, public_key = server.gen_key_pair
        else
          public_key = request_body['public_key']
        end

        key_name = request_body["name"]
        path = data_path(request)

        data = FFI_Yajl::Encoder.encode(
          "name" => key_name,
          "public_key" => public_key,
          "expiration_date" => request_body["expiration_date"]
        )

        create_data(request, path, key_name, data, :create_dir)

        response_body = { "uri" => key_uri(request, key_name) }
        response_body["private_key"] = private_key if generate_keys

        json_response(201, response_body,
                      headers: { "Location" => response_body["uri"] })
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

      def list_key(request, data_path)
        data = FFI_Yajl::Parser.parse(get_data(request, data_path), create_additions: false)
        key_name = data["name"]

        expiration_date = if data["expiration_date"] == "infinity"
          Float::INFINITY
        else
          DateTime.strptime(data["expiration_date"], DATE_FORMAT)
        end

        { "name" => key_name,
          "uri" => key_uri(request, key_name),
          "expired" => DateTime.now > expiration_date }
      end

      def validate_client_or_user!(request)
        # Try loading the client or user so a 404 is returned if it doesn't exist
        path = client?(request) ? request.rest_path[0..3] : request.rest_path[0..1]
        get_data(request, path)
      end

      def client?(request)
        request.rest_path[2] == "clients"
      end

      def key_uri(request, key_name)
        build_uri(request.base_uri, [ *request.rest_path, key_name ])
      end
    end
  end
end
