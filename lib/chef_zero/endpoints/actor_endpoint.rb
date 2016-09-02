require "ffi_yajl"
require "chef_zero/endpoints/rest_object_endpoint"
require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /organizations/ORG/clients/NAME
    # /organizations/ORG/users/NAME
    # /users/NAME
    class ActorEndpoint < RestObjectEndpoint

      def get(request)
        result = super
        user_data = parse_json(result[2])

        user_data.delete("public_key") unless request.api_v0?

        json_response(200, user_data)
      end

      def delete(request)
        result = super

        if request.rest_path[0] == "users"
          list_data(request, [ "organizations" ]).each do |org|
            begin
              delete_data(request, [ "organizations", org, "users", request.rest_path[1] ], :data_store_exceptions)
            rescue DataStore::DataNotFoundError
            end
          end
        end

        delete_actor_keys!(request)
        result
      end

      def put(request)
        # Find out if we're updating the public key.
        request_body = FFI_Yajl::Parser.parse(request.body)

        if request_body["public_key"].nil?
          # If public_key is null, then don't overwrite it.  Weird patchiness.
          body_modified = true
          request_body.delete("public_key")
        else
          updating_public_key = true
        end

        # Generate private_key if requested.
        if request_body.key?("private_key")
          body_modified = true

          if request_body.delete("private_key")
            private_key, public_key = server.gen_key_pair
            updating_public_key = true
            request_body["public_key"] = public_key
          end
        end

        # Put modified body back in `request.body`
        request.body = to_json(request_body) if body_modified

        # PUT /clients is patchy
        request.body = patch_request_body(request)

        result = super(request)

        # Inject private_key into response, delete public_key/password if applicable
        if result[0] == 200 || result[0] == 201
          client_or_user_name = identity_key_value(request) || request.rest_path[-1]

          if is_rename?(request)
            rename_keys!(request, client_or_user_name)
          end

          if request.rest_path[0] == "users"
            response = {
              "uri" => build_uri(request.base_uri, [ "users", client_or_user_name ]),
            }
          else
            response = parse_json(result[2])
          end

          if client?(request)
            response["private_key"] = private_key ? private_key : false
          else
            response["private_key"] = private_key if private_key
            response.delete("public_key") unless updating_public_key
          end

          response.delete("password")

          json_response(result[0], response)
        else
          result
        end
      end

      def populate_defaults(request, response_json)
        response = parse_json(response_json)

        populated_response =
          if client?(request)
            ChefData::DataNormalizer.normalize_client(
              response,
              response["name"] || request.rest_path[-1],
              request.rest_path[1]
            )
          else
            ChefData::DataNormalizer.normalize_user(
              response,
              response["username"] || request.rest_path[-1],
              identity_keys,
              server.options[:osc_compat],
              request.method
            )
          end

        to_json(populated_response)
      end

      private

      # Move key data to new path
      def rename_keys!(request, new_client_or_user_name)
        orig_keys_path = keys_path_base(request)
        new_keys_path = orig_keys_path.dup
                          .tap { |path| path[-2] = new_client_or_user_name }

        key_names = list_data_or_else(request, orig_keys_path, nil)
        return unless key_names # No keys to move

        key_names.each do |key_name|
          # Get old data
          orig_path = [ *orig_keys_path, key_name ]
          data = get_data(request, orig_path, :data_store_exceptions)

          # Copy data to new path
          create_data(
            request,
            new_keys_path, key_name,
            data,
            :create_dir
          )
        end

        # Delete original data
        delete_data_dir(request, orig_keys_path, :recursive, :data_store_exceptions)
      end

      def delete_actor_keys!(request)
        path = keys_path_base(request)[0..-2]
        delete_data_dir(request, path, :recursive, :data_store_exceptions)
      rescue DataStore::DataNotFoundError
      end

      def client?(request, rest_path = nil)
        rest_path ||= request.rest_path
        request.rest_path[2] == "clients"
      end

      # Return the data store keys path for the request client or user, e.g.
      #
      # /organizations/ORG/clients/CLIENT -> /organizations/ORG/client_keys/CLIENT/keys
      # /organizations/ORG/users/USER -> /organizations/ORG/user_keys/USER/keys
      # /users/USER -> /user_keys/USER
      #
      def keys_path_base(request, client_or_user_name = nil)
        rest_path = (rest_path || request.rest_path).dup
        rest_path = rest_path.dup
        case rest_path[-2]
        when "users"
          rest_path[-2] = "user_keys"
        when "clients"
          rest_path[-2] = "client_keys"
        else
          raise "Unexpected URL #{rest_path.join("/")}: cannot determine key path"
        end
        rest_path << "keys"
        rest_path
      end
    end
  end
end
