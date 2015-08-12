require 'ffi_yajl'
require 'chef_zero/rest_base'
require 'chef_zero/endpoints/organization_user_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/users
    class OrganizationUsersEndpoint < RestBase
      def post(request)
        ChefZero::Endpoints::OrganizationUserBase.post(self, request, 'username')
      end

      def get(request)
        ChefZero::Endpoints::OrganizationUserBase.get(self, request) { |username| { "user" => { "username" => username } } }
      end
    end
  end
end
