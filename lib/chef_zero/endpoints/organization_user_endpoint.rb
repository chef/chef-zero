require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/users/NAME
    class OrganizationUserEndpoint < RestBase
      def get(request)
        username = request.rest_path[3]
        get_data(request) # 404 if user is not in org
        user = get_data(request, [ 'users', username ])
        user = FFI_Yajl::Parser.parse(user, :create_additions => false)
        json_response(200, ChefData::DataNormalizer.normalize_user(user, username, ['username'], server.options[:osc_compat], request.method))
      end

      def delete(request)
        user = get_data(request)
        delete_data(request)
        user = FFI_Yajl::Parser.parse(user, :create_additions => false)
        json_response(200, ChefData::DataNormalizer.normalize_user(user, request.rest_path[3], ['username'], server.options[:osc_compat]))
      end

      def post(request)
        orgname = request.rest_path[1]
        username = request.rest_path[3]

        users = get_data(request, [ 'organizations', orgname, 'groups', 'users' ])
        users = FFI_Yajl::Parser.parse(users, :create_additions => false)

        create_data(request, [ 'organizations', orgname, 'users' ], username, '{}')

        # /organizations/ORG/association_requests/USERNAME-ORG
        begin
          delete_data(request, [ 'organizations', orgname, 'association_requests', username], :data_store_exceptions)
        rescue DataStore::DataNotFoundError
        end

        # Add the user to the users group if it isn't already there
        if !users['users'] || !users['users'].include?(username)
          users['users'] ||= []
          users['users'] |= [ username ]
          set_data(request, [ 'organizations', orgname, 'groups', 'users' ], FFI_Yajl::Encoder.encode(users, :pretty => true))
        end
        json_response(200, {})
      end
    end
  end
end
