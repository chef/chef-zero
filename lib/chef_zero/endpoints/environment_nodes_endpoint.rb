require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /environment/NAME/nodes
    class EnvironmentNodesEndpoint < RestBase
      def get(request)
        # 404 if environment does not exist
        get_data(request, request.rest_path[0..1])

        result = {}
        data['nodes'].each_pair do |name, node|
          node_json = JSON.parse(node, :create_additions => false)
          if node['chef_environment'] == request.rest_path[1]
            result[name] = build_uri(request.base_uri, 'nodes', name)
          end
        end
        json_response(200, result)
      end
    end
  end
end
