require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/association_requests/ID
    class OrganizationAssociationRequestEndpoint < RestBase
      def delete(request)
        orgname = request.rest_path[1]
        id = request.rest_path[3]
        if id !~ /(.+)-#{orgname}$/
          raise HttpErrorResponse.new(404, "Invalid ID #{id}.  Must be of the form username-#{orgname}")
        end
        username = $1
        path = request.rest_path[0..-2] + [username]
        data = JSON.parse(get_data(request, path), :create_additions => false)
        delete_data(request, path)
        json_response(200, { "id" => id, "username" => username })
      end
    end
  end
end
