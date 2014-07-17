require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/association_requests
    class OrganizationAssociationRequestsEndpoint < RestBase
      def post(request)
        json = JSON.parse(request.body, :create_additions => false)
        username = json['user']
        orgname = request.rest_path[1]
        id = "#{username}-#{orgname}"

        if !exists_data?(request, [ 'organizations', orgname, 'users', username ])
          RestErrorResponse.new(409, "User #{username} is already in organization #{orgname}")
        end

        create_data(request, request.rest_path, username, '{}')
        json_response(201, { "uri" => build_uri(request.base_uri, request.rest_path + [ id ]) })
      end

      def get(request)
        orgname = request.rest_path[1]
        result = list_data(request).map { |username| { "id" => "#{username}-#{orgname}", 'username' => username } }
        json_response(200, result)
      end
    end
  end
end
