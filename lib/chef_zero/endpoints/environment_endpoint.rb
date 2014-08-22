require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /environments/NAME
    class EnvironmentEndpoint < RestObjectEndpoint
      def delete(request)
        if request.rest_path[3] == "_default"
          # 405, really?
          error(405, "The '_default' environment cannot be modified.")
        else
          super(request)
        end
      end

      def put(request)
        if request.rest_path[3] == "_default"
          error(405, "The '_default' environment cannot be modified.")
        else
          super(request)
        end
      end

      def populate_defaults(request, response_json)
        response = JSON.parse(response_json, :create_additions => false)
        response = ChefData::DataNormalizer.normalize_environment(response, request.rest_path[3])
        JSON.pretty_generate(response)
      end
    end
  end
end
