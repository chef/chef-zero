require "ffi_yajl" unless defined?(FFI_Yajl)
require_relative "rest_object_endpoint"
require_relative "../chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /roles/NAME
    class RoleEndpoint < RestObjectEndpoint
      def populate_defaults(request, response_json)
        role = FFI_Yajl::Parser.parse(response_json)
        role = ChefData::DataNormalizer.normalize_role(role, request.rest_path[3])
        FFI_Yajl::Encoder.encode(role, pretty: true)
      end
    end
  end
end
