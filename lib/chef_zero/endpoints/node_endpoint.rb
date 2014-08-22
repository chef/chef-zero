require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /nodes/ID
    class NodeEndpoint < RestObjectEndpoint
      def populate_defaults(request, response_json)
        node = JSON.parse(response_json, :create_additions => false)
        node = ChefData::DataNormalizer.normalize_node(node, request.rest_path[3])
        JSON.pretty_generate(node)
      end
    end
  end
end

