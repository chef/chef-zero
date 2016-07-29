require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    class CookbookArtifactEndpoint < RestBase
      # GET /organizations/ORG/cookbook_artifacts/COOKBOOK
      def get(request)
        cookbook_name = request.rest_path.last
        cookbook_url = build_uri(request.base_uri, request.rest_path)
        response_data = {}
        versions = []

        list_data(request).each do |identifier|
          artifact_url = build_uri(request.base_uri, request.rest_path + [cookbook_name, identifier])
          versions << { url: artifact_url, identifier: identifier }
        end

        response_data[cookbook_name] = { url: cookbook_url, versions: versions }

        return json_response(200, response_data)
      end
    end
  end
end
