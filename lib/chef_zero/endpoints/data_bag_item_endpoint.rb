require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/endpoints/data_bag_item_endpoint'
require 'chef_zero/data_normalizer'

module ChefZero
  module Endpoints
    # /data/NAME/NAME
    class DataBagItemEndpoint < RestObjectEndpoint
      def initialize(server)
        super(server, 'id')
      end

      def populate_defaults(request, response_json)
        DataBagItemEndpoint::populate_defaults(request, response_json, request.rest_path[1], request.rest_path[2])
      end

      def self.populate_defaults(request, response_json, data_bag, data_bag_item)
        response = JSON.parse(response_json, :create_additions => false)
        response = DataNormalizer.normalize_data_bag_item(response, data_bag, data_bag_item, request.method)
        JSON.pretty_generate(response)
      end
    end
  end
end
