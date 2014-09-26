require 'ffi_yajl'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /nodes/ID
    class NodeEndpoint < RestObjectEndpoint
      def populate_defaults(request, response_json)
        node = FFI_Yajl::Parser.parse(response_json, :create_additions => false)
        node = ChefData::DataNormalizer.normalize_node(node, request.rest_path[3])
        FFI_Yajl::Encoder.encode(node, :pretty => true)
      end
    end
  end
end

