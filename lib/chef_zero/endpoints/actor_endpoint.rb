require 'ffi_yajl'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /organizations/ORG/clients/NAME
    # /organizations/ORG/users/NAME
    # /users/NAME
    class ActorEndpoint < RestObjectEndpoint
      DEFAULT_PUBLIC_KEY_NAME = "default"
      DEFAULT_PUBLIC_KEY_EXPIRATION_DATE = "infinity"

      def delete(request)
        result = super
        username = request.rest_path[1]

        if request.rest_path[0] == 'users'
          list_data(request, [ 'organizations' ]).each do |org|
            begin
              delete_data(request, [ 'organizations', org, 'users', username ], :data_store_exceptions)
            rescue DataStore::DataNotFoundError
            end
          end

          begin
            path = [ 'user_keys', username ]
            delete_data_dir(request, path, :data_store_exceptions)
          rescue DataStore::DataNotFoundError
          end
        end
        result
      end

      def put(request)
        # Find out if we're updating the public key.
        request_body = FFI_Yajl::Parser.parse(request.body, :create_additions => false)

        public_key = request_body.delete('public_key')

        if public_key.nil?
          # If public_key is null, then don't overwrite it.  Weird patchiness.
          body_modified = true
        else
          updating_public_key = true
        end

        # Generate private_key if requested.
        if request_body.key?('private_key')
          body_modified = true

          if request_body.delete('private_key')
            private_key, public_key = server.gen_key_pair
            updating_public_key = true
          end
        end

        # Put modified body back in `request.body`
        request.body = FFI_Yajl::Encoder.encode(request_body, :pretty => true) if body_modified

        # PUT /clients is patchy
        request.body = patch_request_body(request, except: :public_key)

        result = super(request)

        # Inject private_key into response, delete public_key/password if applicable
        if result[0] == 200 || result[0] == 201
          username = identity_key_value(request) || request.rest_path[-1]

          # TODO Implement for clients
          if request.rest_path[2] != 'clients' && is_rename?(request)
            rename_user_keys!(request, username)
          end

          if request.rest_path[0] == 'users'
            response = {
              'uri' => build_uri(request.base_uri, [ 'users', username ])
            }
          else
            response = FFI_Yajl::Parser.parse(result[2], :create_additions => false)
          end

          if request.rest_path[2] == 'clients'
            response['private_key'] = private_key ? private_key : false
          else
            response['private_key'] = private_key if private_key

            if updating_public_key
              update_user_default_key!(request, public_key)
            end
          end

          if request.rest_path[2] == 'users' && !updating_public_key
            response.delete('public_key')
          end

          response.delete('password')

          json_response(result[0], response)
        else
          result
        end
      end

      private

      def populate_defaults(request, response_json)
        response = FFI_Yajl::Parser.parse(response_json, :create_additions => false)

        response =
          if request.rest_path[2] == 'clients'
            ChefData::DataNormalizer.normalize_client(response, request.rest_path[3], request.rest_path[1])
          else
            public_key = get_user_default_public_key(request, response['username'])

            if public_key
              response['public_key'] = public_key
            end

            ChefData::DataNormalizer.normalize_user(response, request.rest_path[3], identity_keys, server.options[:osc_compat], request.method)
          end

        FFI_Yajl::Encoder.encode(response, :pretty => true)
      end

      # Returns the user's default public_key from user_keys store
      def get_user_default_public_key(request, username)
        path = [ "user_keys", username, "keys", DEFAULT_PUBLIC_KEY_NAME ]
        key_json = get_data(request, path, :nil)
        return unless key_json

        key_data = FFI_Yajl::Parser.parse(key_json, create_additions: false)
        key_data && key_data["public_key"]
      end

      # Move key data to new path
      def rename_user_keys!(request, new_username)
        orig_username = request.rest_path[-1]
        orig_user_keys_path = [ 'user_keys', orig_username, 'keys' ]
        new_user_keys_path = [ 'user_keys', new_username, 'keys' ]

        user_key_names = list_data(request, orig_user_keys_path, :data_store_exceptions)

        user_key_names.each do |key_name|
          # Get old data
          orig_path = orig_user_keys_path + [ key_name ]
          data = get_data(request, orig_path, :data_store_exceptions)

          # Copy data to new path
          create_data(
            request,
            new_user_keys_path, key_name,
            data,
            :create_dir
          )
        end

        # Delete original data
        delete_data_dir(request, orig_user_keys_path, :data_store_exceptions)
      end

      def update_user_default_key!(request, public_key)
        username = request.rest_path[1]
        path = [ "user_keys", username, "keys", DEFAULT_PUBLIC_KEY_NAME ]

        data = FFI_Yajl::Encoder.encode(
          "name" => DEFAULT_PUBLIC_KEY_NAME,
          "public_key" => public_key,
          "expiration_date" => DEFAULT_PUBLIC_KEY_EXPIRATION_DATE
        )

        set_data(request, path, data, :create, :data_store_exceptions)
      end
    end
  end
end
