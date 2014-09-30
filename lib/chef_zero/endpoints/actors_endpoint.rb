require 'ffi_yajl'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /clients or /users
    class ActorsEndpoint < RestListEndpoint
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
          response['public_key'] = public_key
          json_response(201, response)
        else
          result
        end
      end
    end
  end
end
