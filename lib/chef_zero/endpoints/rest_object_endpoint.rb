require 'json'
require 'chef_zero/rest_base'
require 'chef_zero/rest_error_response'

module ChefZero
  module Endpoints
    # Typical REST leaf endpoint (/roles/NAME or /data/BAG/NAME)
    class RestObjectEndpoint < RestBase
      def initialize(server, identity_key = 'name')
        super(server)
        @identity_key = identity_key
      end

      attr_reader :identity_key

      def get(request)
        already_json_response(200, populate_defaults(request, get_data(request)))
      end

      def put(request)
        # We grab the old body to trigger a 404 if it doesn't exist
        old_body = get_data(request)
        request_json = JSON.parse(request.body, :create_additions => false)
        key = request_json[identity_key] || request.rest_path[-1]
        # If it's a rename, check for conflict and delete the old value
        rename = key != request.rest_path[-1]
        if rename
          begin
            data_store.create(request.rest_path[0..1] + request.rest_path[2..-2], key, request.body)
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
          request_json = JSON.parse(request.body, :create_additions => false)
          existing_json = JSON.parse(existing_value, :create_additions => false)
          merged_json = existing_json.merge(request_json)
          if merged_json.size > request_json.size
            return JSON.pretty_generate(merged_json)
          end
        end
        request.body
      end
    end
  end
end
