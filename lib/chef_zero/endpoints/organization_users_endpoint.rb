require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/users
    class OrganizationUsersEndpoint < RestBase
      def get(request)
        result = list_data(request).map { |username| { "user" => { "username" => username } } }
        json_response(200, result)
      end
    end
  end
end
