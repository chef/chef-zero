require "ffi_yajl"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /users/NAME/association_requests/count
    class UserAssociationRequestsCountEndpoint < RestBase
      def get(request)
        get_data(request, request.rest_path[0..-3])

        username = request.rest_path[1]
        result = list_data(request, [ "organizations" ]).select do |org|
          exists_data?(request, [ "organizations", org, "association_requests", username ])
        end
        json_response(200, { "value" => result.size })
      end
    end
  end
end
