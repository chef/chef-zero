require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /users/USER/organizations
    class UserOrganizationsEndpoint < RestBase
      def get(request)
        username = request.rest_path[1]
        result = list_data(request, [ 'organizations' ]).select do |orgname|
          exists_data?(request, [ 'organizations', orgname, 'users', username ])
        end
        result = result.map do |orgname|
          org = get_data(request, [ 'organizations', orgname, 'org' ])
          org = FFI_Yajl::Parser.parse(org, :create_additions => false)
          ChefData::DataNormalizer.normalize_organization(org, orgname)
        end
        json_response(200, result)
      end
    end
  end
end
