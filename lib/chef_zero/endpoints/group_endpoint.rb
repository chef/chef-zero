require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /organizations/ORG/groups/NAME
    class GroupEndpoint < RestObjectEndpoint
      def initialize(server)
        super(server, %w(id groupname))
      end

      def populate_defaults(request, response_json)
        group = JSON.parse(response_json, :create_additions => false)
        group = ChefData::DataNormalizer.normalize_group(group, request.rest_path[3], request.rest_path[1])
        JSON.pretty_generate(group)
      end
    end
  end
end
