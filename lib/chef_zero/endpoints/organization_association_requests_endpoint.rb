require 'json'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /organizations/ORG/association_requests
    class OrganizationAssociationRequestsEndpoint < RestBase
      def post(request)
        json = JSON.parse(request.body, :create_additions => false)
        username = json['user']
        orgname = request.rest_path[1]
        id = "#{username}-#{orgname}"
        create_data(request, request.rest_path, id, '{}')
        json_response(201, { "uri" => build_uri(request.base_uri, request.rest_path + [ id ]) })
      end

      def get(request)
        requests = list_data(request)
        result = list_data(request).map do |id|
          json = JSON.parse(get_data(request, request.rest_path + [ id ]), :create_additions => false)
          DataNormalizer.normalize_association_request(json, id, nil, request.rest_path[1])
        end
        json_response(200, result)
      end
    end
  end
end
