require "ffi_yajl"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /environment/NAME/nodes
    class EnvironmentNodesEndpoint < RestBase
      def get(request)
        # 404 if environment does not exist
        get_data(request, request.rest_path[0..3])

        result = {}
        list_data(request, request.rest_path[0..1] + ["nodes"]).each do |name|
          node = FFI_Yajl::Parser.parse(get_data(request, request.rest_path[0..1] + ["nodes", name]))
          if node["chef_environment"] == request.rest_path[3]
            result[name] = build_uri(request.base_uri, request.rest_path[0..1] + ["nodes", name])
          end
        end
        json_response(200, result)
      end
    end
  end
end
