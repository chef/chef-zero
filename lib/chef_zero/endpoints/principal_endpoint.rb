require "ffi_yajl"
require "chef_zero"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /principals/NAME
    class PrincipalEndpoint < RestBase
      def get(request)
        name = request.rest_path[-1]
        # If /organizations/ORG/users/NAME exists, use this user (only org members have precedence over clients).        hey are an org member.
        json = get_data(request, request.rest_path[0..1] + [ "users", name ], :nil)
        if json
          type = "user"
          org_member = true
        else
          # If /organizations/ORG/clients/NAME exists, use the client.
          json = get_data(request, request.rest_path[0..1] + [ "clients", name ], :nil)
          if json
            type = "client"
            org_member = true
          else
            # If there is no client with that name, check for a user (/users/NAME) and return that with
            # org_member = false.
            json = get_data(request, [ "users", name ], :nil)
            if json
              type = "user"
              org_member = false
            end
          end
        end
        if json
          principal_data = {
            "name" => name,
            "type" => type,
            "public_key" => FFI_Yajl::Parser.parse(json)["public_key"] || PUBLIC_KEY,
            "authz_id" => "0" * 32,
            "org_member" => org_member,
          }

          response_data =
            if request.api_v0?
              principal_data
            else
              { "principals" => [ principal_data ] }
            end

          json_response(200, response_data)
        else
          error(404, "Principal not found")
        end
      end
    end
  end
end
