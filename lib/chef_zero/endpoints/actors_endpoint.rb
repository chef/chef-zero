require 'ffi_yajl'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /users, /organizations/ORG/clients or /organizations/ORG/users
    class ActorsEndpoint < RestListEndpoint
      def get(request)
        response = super(request)

        if request.query_params['email']
          results = FFI_Yajl::Parser.parse(response[2], :create_additions => false)
          new_results = {}
          results.each do |name, url|
            record = get_data(request, request.rest_path + [ name ], :nil)
            if record
              record = FFI_Yajl::Parser.parse(record, :create_additions => false)
              new_results[name] = url if record['email'] == request.query_params['email']
            end
          end
          response[2] = FFI_Yajl::Encoder.encode(new_results, :pretty => true)
        end

        if request.query_params['verbose']
          results = FFI_Yajl::Parser.parse(response[2], :create_additions => false)
          results.each do |name, url|
            record = get_data(request, request.rest_path + [ name ], :nil)
            if record
              record = FFI_Yajl::Parser.parse(record, :create_additions => false)
              record = ChefData::DataNormalizer.normalize_user(record, name, identity_keys, server.options[:osc_compat])
              results[name] = record
            end
          end
          response[2] = FFI_Yajl::Encoder.encode(results, :pretty => true)
        end
        response
      end

      def post(request)
        # First, find out if the user actually posted a public key.  If not, make
        # one.
        request_body = FFI_Yajl::Parser.parse(request.body, :create_additions => false)
        public_key = request_body['public_key']
        if !public_key
          private_key, public_key = server.gen_key_pair
          request_body['public_key'] = public_key
          request.body = FFI_Yajl::Encoder.encode(request_body, :pretty => true)
        end

        result = super(request)

        if result[0] == 201
          # If we generated a key, stuff it in the response.
          response = FFI_Yajl::Parser.parse(result[2], :create_additions => false)
          response['private_key'] = private_key if private_key
          response['public_key'] = public_key unless request.rest_path[0] == 'users'
          json_response(201, response)
        else
          result
        end
      end
    end
  end
end
