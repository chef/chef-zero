require 'ffi_yajl'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /roles/NAME
    class RoleEndpoint < RestObjectEndpoint
      def populate_defaults(request, response_json)
        role = FFI_Yajl::Parser.parse(response_json, :create_additions => false)
        role = ChefData::DataNormalizer.normalize_role(role, request.rest_path[3])
        FFI_Yajl::Encoder.encode(role, :pretty => true)
      end
    end
  end
end
