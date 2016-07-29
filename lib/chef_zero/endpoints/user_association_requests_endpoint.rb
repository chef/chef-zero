require "ffi_yajl"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /users/USER/association_requests
    class UserAssociationRequestsEndpoint < RestBase
      def get(request)
        get_data(request, request.rest_path[0..-2])
        username = request.rest_path[1]
        result = list_data(request, [ "organizations" ]).select do |org|
          exists_data?(request, [ "organizations", org, "association_requests", username ])
        end
        result = result.map { |org| { "id" => "#{username}-#{org}", "orgname" => org } }
        json_response(200, result)
      end
    end
  end
end
