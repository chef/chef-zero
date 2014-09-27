require 'ffi_yajl'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /organizations/ORG/clients/NAME
    # /organizations/ORG/users/NAME
    # /users/NAME
    class ActorEndpoint < RestObjectEndpoint
      def delete(request)
        result = super
        if request.rest_path[0] == 'users'
          list_data(request, [ 'organizations' ]).each do |org|
            begin
              delete_data(request, [ 'organizations', org, 'users', request.rest_path[1] ], :data_store_exceptions)
            rescue DataStore::DataNotFoundError
            end
          end
        end
        result
      end

      def put(request)
        # Find out if we're updating the public key.
        request_body = FFI_Yajl::Parser.parse(request.body, :create_additions => false)
        if request_body['public_key'].nil?
          # If public_key is null, then don't overwrite it.  Weird patchiness.
          body_modified = true
          request_body.delete('public_key')
        else
          updating_public_key = true
        end

        # Generate private_key if requested.
        if request_body.has_key?('private_key')
          body_modified = true
          if request_body['private_key']
            private_key, public_key = server.gen_key_pair
            updating_public_key = true
            request_body['public_key'] = public_key
          end
          request_body.delete('private_key')
        end

        # Save request
        request.body = FFI_Yajl::Encoder.encode(request_body, :pretty => true) if body_modified

        # PUT /clients is patchy
        request.body = patch_request_body(request)

        result = super(request)

        # Inject private_key into response, delete public_key/password if applicable
        if result[0] == 200 || result[0] == 201
          if request.rest_path[0] == 'users'
            key = nil
            identity_keys.each do |identity_key|
              key ||= request_body[identity_key]
            end
            key ||= request.rest_path[-1]
            response = {
              'uri' => build_uri(request.base_uri, [ 'users', key ])
            }
          else
            response = FFI_Yajl::Parser.parse(result[2], :create_additions => false)
          end
          response['private_key'] = private_key if private_key
          response.delete('public_key') if !updating_public_key && request.rest_path[2] == 'users'
          response.delete('password')
          json_response(result[0], response)
        else
          result
        end
      end

      def populate_defaults(request, response_json)
        response = FFI_Yajl::Parser.parse(response_json, :create_additions => false)
        if request.rest_path[2] == 'clients'
          response = ChefData::DataNormalizer.normalize_client(response, request.rest_path[3])
        else
          response = ChefData::DataNormalizer.normalize_user(response, request.rest_path[3], identity_keys, server.options[:osc_compat], request.method)
        end
        FFI_Yajl::Encoder.encode(response, :pretty => true)
      end
    end
  end
end
