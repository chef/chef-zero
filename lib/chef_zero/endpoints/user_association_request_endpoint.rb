require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /users/USER/association_requests/ID
    class UserAssociationRequestEndpoint < RestBase
      def put(request)
        username = request.rest_path[1]
        id = request.rest_path[3]
        if id !~ /^#{username}-(.+)/
          raise RestErrorResponse.new(400, "Association request #{id} is invalid.  Must be #{username}-orgname.")
        end
        orgname = $1

        json = JSON.parse(request.body, :create_additions => false)
        association_request_path = [ 'organizations', orgname, 'association_requests', username ]
        if json['response'] == 'accept'
          delete_data(request, association_request_path)
          create_data(request, [ 'organizations', orgname, 'users' ], username, '{}')
        elsif json['response'] == 'reject'
          delete_data(request, association_request_path)
        else
          raise RestErrorResponse.new(400, "response parameter was missing or set to the wrong value (must be accept or reject)")
        end
        json_response(200, { 'organization' => { 'name' => orgname } })
      end
    end
  end
end
