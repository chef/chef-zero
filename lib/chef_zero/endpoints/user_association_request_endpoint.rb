require 'ffi_yajl'
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

        json = FFI_Yajl::Parser.parse(request.body, :create_additions => false)
        association_request_path = [ 'organizations', orgname, 'association_requests', username ]
        if json['response'] == 'accept'
          users = get_data(request, [ 'organizations', orgname, 'groups', 'users' ])
          users = FFI_Yajl::Parser.parse(users, :create_additions => false)

          delete_data(request, association_request_path)
          create_data(request, [ 'organizations', orgname, 'users' ], username, '{}')

          # Add the user to the users group if it isn't already there
          if !users['users'] || !users['users'].include?(username)
            users['users'] ||= []
            users['users'] |= [ username ]
            set_data(request, [ 'organizations', orgname, 'groups', 'users' ], FFI_Yajl::Encoder.encode(users, :pretty => true))
          end
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
