require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/data_normalizer'

module ChefZero
  module Endpoints
    # /roles/NAME
    class RoleEndpoint < RestObjectEndpoint
      def populate_defaults(request, response_json)
        role = JSON.parse(response_json, :create_additions => false)
        role = DataNormalizer.normalize_role(role, request.rest_path[1])
        JSON.pretty_generate(role)
      end
    end
  end
end
