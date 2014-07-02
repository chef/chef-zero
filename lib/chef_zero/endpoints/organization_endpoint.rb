require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /organizations/NAME
    class OrganizationEndpoint < RestBase
      def get(request)
        org = get_data(request, request.rest_path + [ 'org' ])
        already_json_response(200, populate_defaults(request, org))
      end

      def put(request)
        org = JSON.parse(get_data(request, request.rest_path + [ 'org' ]), :create_additions => false)
        new_org = JSON.parse(request.body, :create_additions => false)
        new_org.each do |key, value|
          org[key] = value
        end
        org = JSON.pretty_generate(org)
        set_data(request, request.rest_path + [ 'org' ], org)
        already_json_response(200, populate_defaults(request, org))
      end

      def delete(request)
        org = get_data(request, request.rest_path + [ 'org' ])
        delete_data_dir(request, request.rest_path)
        already_json_response(200, populate_defaults(request, org))
      end

      def populate_defaults(request, response_json)
        org = JSON.parse(response_json, :create_additions => false)
        org = DataNormalizer.normalize_organization(org, request.rest_path[1])
        JSON.pretty_generate(org)
      end
    end
  end
end
