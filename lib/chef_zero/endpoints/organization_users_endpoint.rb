require "ffi_yajl"
require "chef_zero/rest_base"
require "chef_zero/endpoints/organization_user_base"

module ChefZero
  module Endpoints
    # /organizations/ORG/users
    class OrganizationUsersEndpoint < RestBase
      def post(request)
        orgname = request.rest_path[1]
        json = FFI_Yajl::Parser.parse(request.body)
        username = json["username"]

        if exists_data?(request, [ "organizations", orgname, "users", username ])
          raise RestErrorResponse.new(409, "User #{username} is already in organization #{orgname}")
        end

        users = get_data(request, [ "organizations", orgname, "groups", "users" ])
        users = FFI_Yajl::Parser.parse(users)

        create_data(request, request.rest_path, username, "{}")

        # /organizations/ORG/association_requests/USERNAME-ORG
        begin
          delete_data(request, [ "organizations", orgname, "association_requests", username], :data_store_exceptions)
        rescue DataStore::DataNotFoundError
        end

        # Add the user to the users group if it isn't already there
        if !users["users"] || !users["users"].include?(username)
          users["users"] ||= []
          users["users"] |= [ username ]
          set_data(request, [ "organizations", orgname, "groups", "users" ], FFI_Yajl::Encoder.encode(users, :pretty => true))
        end
        json_response(201, { "uri" => build_uri(request.base_uri, request.rest_path + [ username ]) })
      end

      def get(request)
        ChefZero::Endpoints::OrganizationUserBase.get(self, request) { |username| { "user" => { "username" => username } } }
      end
    end
  end
end
