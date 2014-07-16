require 'json'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /organizations/ORG/association_requests/ID
    class OrganizationAssociationRequestEndpoint < RestBase
      def delete(request)
        data = JSON.parse(get_data(request), :create_additions => false)
        delete_data(request)
        orgname = request.rest_path[1]
        id = request.rest_path[3]
        json_response(200, DataNormalizer.normalize_association_request(data, id, nil, orgname))
      end
    end
  end
end
