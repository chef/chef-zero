require "ffi_yajl"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /organizations/ORG/association_requests
    class OrganizationAssociationRequestsEndpoint < RestBase
      def post(request)
        json = FFI_Yajl::Parser.parse(request.body)
        username = json["user"]
        orgname = request.rest_path[1]
        id = "#{username}-#{orgname}"

        if exists_data?(request, [ "organizations", orgname, "users", username ])
          raise RestErrorResponse.new(409, "User #{username} is already in organization #{orgname}")
        end

        create_data(request, request.rest_path, username, "{}")
        json_response(201, { "uri" => build_uri(request.base_uri, request.rest_path + [ id ]) })
      end

      def get(request)
        orgname = request.rest_path[1]
        ChefZero::Endpoints::OrganizationUserBase.get(self, request) do |username|
          { "id" => "#{username}-#{orgname}", "username" => username }
        end
      end
    end
  end
end
