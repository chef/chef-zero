require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/data_normalizer'

module ChefZero
  module Endpoints
    # /clients/* and /users/*
    class ActorEndpoint < RestObjectEndpoint
      def put(request)
        # Find out if we're updating the public key.
        request_body = JSON.parse(request.body, :create_additions => false)
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
        request.body = JSON.pretty_generate(request_body) if body_modified

        # PUT /clients is patchy
        request.body = patch_request_body(request)

        result = super(request)

        # Inject private_key into response, delete public_key/password if applicable
        if result[0] == 200
          response = JSON.parse(result[2], :create_additions => false)
          response['private_key'] = private_key if private_key
          response.delete('public_key') if !updating_public_key && request.rest_path[0] == 'users'
          response.delete('password')
          # For PUT /clients, a rename returns 201.
          if request_body['name'] && request.rest_path[1] != request_body['name']
            json_response(201, response)
          else
            json_response(200, response)
          end
        else
          result
        end
      end

      def populate_defaults(request, response_json)
        response = JSON.parse(response_json, :create_additions => false)
        if request.rest_path[0] == 'clients'
          response = DataNormalizer.normalize_client(response, request.rest_path[1])
        else
          response = DataNormalizer.normalize_user(response, request.rest_path[1])
        end
        JSON.pretty_generate(response)
      end
    end
  end
end

