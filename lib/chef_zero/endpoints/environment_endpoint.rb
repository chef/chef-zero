require "ffi_yajl" unless defined?(FFI_Yajl)
require_relative "rest_object_endpoint"
require_relative "../chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /environments/NAME
    class EnvironmentEndpoint < RestObjectEndpoint
      def delete(request)
        if request.rest_path[3] == "_default"
          # 405, really?
          error(405, "The '_default' environment cannot be modified.")
        else
          super(request)
        end
      end

      def put(request)
        if request.rest_path[3] == "_default"
          error(405, "The '_default' environment cannot be modified.")
        else
          super(request)
        end
      end

      def populate_defaults(request, response_json)
        response = FFI_Yajl::Parser.parse(response_json)
        response = ChefData::DataNormalizer.normalize_environment(response, request.rest_path[3])
        FFI_Yajl::Encoder.encode(response, pretty: true)
      end
    end
  end
end
