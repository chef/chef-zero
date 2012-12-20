require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/data_normalizer'

module ChefZero
  module Endpoints
    # /nodes/ID
    class NodeEndpoint < RestObjectEndpoint
      def populate_defaults(request, response_json)
        node = JSON.parse(response_json, :create_additions => false)
        node = DataNormalizer.normalize_node(node, request.rest_path[1])
        JSON.pretty_generate(node)
      end
    end
  end
end

