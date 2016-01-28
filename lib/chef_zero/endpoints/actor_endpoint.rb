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
        client_or_user_name = request.rest_path.last

        if request.rest_path[0] == 'users'
          list_data(request, [ 'organizations' ]).each do |org|
            begin
              delete_data(request, [ 'organizations', org, 'users', client_or_user_name ], :data_store_exceptions)
            rescue DataStore::DataNotFoundError
            end
          end
        end

        delete_actor_keys!(request, client_or_user_name)
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
          client_or_user_name = identity_key_value(request) || request.rest_path[-1]

          if is_rename?(request)
            rename_keys!(request, client_or_user_name)
          end

          if request.rest_path[0] == 'users'
            response = {
              'uri' => build_uri(request.base_uri, [ 'users', client_or_user_name ])
            }
          else
            response = FFI_Yajl::Parser.parse(result[2], :create_additions => false)
          end

          if updating_public_key
            update_default_public_key!(request, client_or_user_name, public_key)
            response['public_key'] = public_key
          end

          if client?(request)
            response['private_key'] = private_key ? private_key : false
          else
            response['private_key'] = private_key if private_key
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

        client_or_user_name =
          if client?(request)
            response["name"]
          else
            response["username"]
          end || request.rest_path.last

        response =
          if client?(request)
            ChefData::DataNormalizer.normalize_client(
              data_store,
              response,
              client_or_user_name,
              request.rest_path[1]
            )
          else
            ChefData::DataNormalizer.normalize_user(
              data_store,
              response,
              client_or_user_name,
              identity_keys,
              server.options[:osc_compat],
              request.method
            )
          end

        FFI_Yajl::Encoder.encode(response, :pretty => true)
      end

      # Move key data to new path
      def rename_keys!(request, new_client_or_user_name)
        orig_client_or_user_name = request.rest_path.last

        path_root = "#{client_or_user(request)}_keys"
        orig_keys_path = [ path_root, orig_client_or_user_name, "keys" ]
        new_keys_path = [ path_root, new_client_or_user_name, "keys" ]

        key_names = list_data(request, orig_keys_path, :data_store_exceptions)

        key_names.each do |key_name|
          # Get old data
          orig_path = orig_keys_path + [ key_name ]
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

      def update_default_public_key!(request, client_or_user_name, public_key)
        path = [ "#{client_or_user(request)}_keys", client_or_user_name,
                 "keys", DEFAULT_PUBLIC_KEY_NAME ]

        data = FFI_Yajl::Encoder.encode(
          "name" => DEFAULT_PUBLIC_KEY_NAME,
          "public_key" => public_key,
          "expiration_date" => DEFAULT_PUBLIC_KEY_EXPIRATION_DATE
        )

        set_data(request, path, data, :create, :data_store_exceptions)
      end

      def delete_actor_keys!(request, client_or_user_name)
        path = [ "#{client_or_user(request)}_keys", client_or_user_name ]
        delete_data_dir(request, path, :recursive, :data_store_exceptions)
      rescue DataStore::DataNotFoundError
      end

      def client_or_user(request)
        request.rest_path[2] == "clients" ? :client : :user
      end

      def client?(request)
        client_or_user(request) == :client
      end
    end
  end
end
