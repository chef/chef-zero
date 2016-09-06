require "ffi_yajl"
require "chef_zero/rest_base"
require "chef_zero/rest_error_response"

module ChefZero
  module Endpoints
    # Typical REST leaf endpoint (/roles/NAME or /data/BAG/NAME)
    class RestObjectEndpoint < RestBase
      def initialize(server, identity_keys = [ "name" ])
        super(server)
        identity_keys = [ identity_keys ] if identity_keys.is_a?(String)
        @identity_keys = identity_keys
      end

      attr_reader :identity_keys

      def get(request)
        already_json_response(200, populate_defaults(request, get_data(request)))
      end

      def put(request)
        # We grab the old body to trigger a 404 if it doesn't exist
        old_body = get_data(request)

        # If it's a rename, check for conflict and delete the old value
        if is_rename?(request)
          key = identity_key_value(request)

          begin
            create_data(request, request.rest_path[0..-2], key, request.body, :data_store_exceptions)
          rescue DataStore::DataAlreadyExistsError
            return error(409, "Cannot rename '#{request.rest_path[-1]}' to '#{key}': '#{key}' already exists")
          end
          delete_data(request)
          already_json_response(201, populate_defaults(request, request.body))
        else
          set_data(request, request.rest_path, request.body)
          already_json_response(200, populate_defaults(request, request.body))
        end
      end

      def delete(request)
        result = get_data(request)
        delete_data(request)
        already_json_response(200, populate_defaults(request, result))
      end

      def patch_request_body(request)
        existing_value = get_data(request, nil, :nil)
        if existing_value
          request_json = FFI_Yajl::Parser.parse(request.body)
          existing_json = FFI_Yajl::Parser.parse(existing_value)
          merged_json = existing_json.merge(request_json)
          if merged_json.size > request_json.size
            return FFI_Yajl::Encoder.encode(merged_json, :pretty => true)
          end
        end

        request.body
      end

      private

      # Get the value of the (first existing) identity key from the request body or nil
      def identity_key_value(request)
        request_json = parse_json(request.body)
        identity_keys.map { |k| request_json[k] }.compact.first
      end

      # Does this request change the value of the identity key?
      def is_rename?(request)
        return false unless key = identity_key_value(request)
        key != request.rest_path[-1]
      end
    end
  end
end
