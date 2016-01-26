require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /users/USER/keys
    # /organizations/ORG/clients/CLIENT/keys
    class ActorKeysEndpoint < RestBase
      DATE_FORMAT = "%FT%TZ" # e.g. 2015-12-24T21:00:00Z

      def get(request)
        username = request.rest_path[1]
        path = [ "user_keys", username, "keys" ]

        result = list_data(request, path).map do |key_name|
          list_key(request, [ *path, key_name ])
        end

        json_response(200, result)
      end

      def post(request)
        username = request.rest_path[1]
        request_body = FFI_Yajl::Parser.parse(request.body)

        validate_user!(request)

        generate_keys = request_body["public_key"].nil?

        if generate_keys
          private_key, public_key = server.gen_key_pair
        else
          public_key = request_body['public_key']
        end

        key_name = request_body["name"]
        path = [ "user_keys", username, "keys" ]

        data = FFI_Yajl::Encoder.encode(
          "name" => key_name,
          "public_key" => public_key,
          "expiration_date" => request_body["expiration_date"]
        )

        create_data(request, path, key_name, data, :create_dir)

        response_body = {
          "uri" => build_uri(request.base_uri,
                     [ "users", username, "keys", key_name ])
        }
        response_body["private_key"] = private_key if generate_keys

        json_response(201, response_body,
                      headers: { "Location" => response_body["uri"] })
      end

      private

      def list_key(request, data_path)
        data = FFI_Yajl::Parser.parse(get_data(request, data_path), create_additions: false)
        uri = build_uri(request.base_uri, [ "users", *data_path[1..-1] ])

        expiration_date = if data["expiration_date"] == "infinity"
          Float::INFINITY
        else
          DateTime.strptime(data["expiration_date"], DATE_FORMAT)
        end

        { "name" => data_path[-1],
          "uri" => uri,
          "expired" => DateTime.now > expiration_date }
      end

      def validate_user!(request)
        # Try loading the user so a 404 is returned if the user doesn't
        get_data(request, request.rest_path[0, 2])
      end
    end
  end
end
