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
        list_data(request, ['nodes']).each do |name|
          node = JSON.parse(get_data(request, ['nodes', name]), :create_additions => false)
          if node['chef_environment'] == request.rest_path[1]
            result[name] = build_uri(request.base_uri, 'nodes', name)
          end
        end
        json_response(200, result)
      end
    end
  end
end
