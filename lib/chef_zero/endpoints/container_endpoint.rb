require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/data_normalizer'

module ChefZero
  module Endpoints
    # /organizations/ORG/containers/NAME
    class ContainerEndpoint < RestObjectEndpoint
      def initialize(server)
        super(server, %w(id containername))
      end

      undef_method(:put)

      def populate_defaults(request, response_json)
        container = JSON.parse(response_json, :create_additions => false)
        container = DataNormalizer.normalize_container(container, request.rest_path[3])
        JSON.pretty_generate(container)
      end
    end
  end
end
