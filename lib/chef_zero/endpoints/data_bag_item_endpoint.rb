require "ffi_yajl"
require "chef_zero/endpoints/rest_object_endpoint"
require "chef_zero/endpoints/data_bag_item_endpoint"
require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /data/NAME/NAME
    class DataBagItemEndpoint < RestObjectEndpoint
      def initialize(server)
        super(server, "id")
      end

      def populate_defaults(request, response_json)
        DataBagItemEndpoint.populate_defaults(request, response_json, request.rest_path[3], request.rest_path[4])
      end

      def self.populate_defaults(request, response_json, data_bag, data_bag_item)
        response = FFI_Yajl::Parser.parse(response_json)
        response = ChefData::DataNormalizer.normalize_data_bag_item(response, data_bag, data_bag_item, request.method)
        FFI_Yajl::Encoder.encode(response, :pretty => true)
      end
    end
  end
end
