require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/association_requests
    class OrganizationAssociationRequestsEndpoint < RestBase
      def post(request)
        ChefZero::Endpoints::OrganizationUserBase.post(self, request, 'user')
      end

      def get(request)
        orgname = request.rest_path[1]
        ChefZero::Endpoints::OrganizationUserBase.get(self, request) do |username|
          { "id" => "#{username}-#{orgname}", 'username' => username }
        end
      end
    end
  end
end
