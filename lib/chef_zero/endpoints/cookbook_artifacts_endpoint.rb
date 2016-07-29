require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    class CookbookArtifactsEndpoint < RestBase
      # GET /organizations/ORG/cookbook_artifacts
      def get(request)
        data = {}

        artifacts = begin
          list_data(request)
        rescue Exception => e
          if e.response_code == 404
            return already_json_response(200, "{}")
          end
        end

        artifacts.each do |cookbook_artifact|
          cookbook_url = build_uri(request.base_uri, request.rest_path + [cookbook_artifact])

          versions = []
          list_data(request, request.rest_path + [cookbook_artifact]).each do |identifier|
            artifact_url = build_uri(request.base_uri, request.rest_path + [cookbook_artifact, identifier])
            versions << { url: artifact_url, identifier: identifier }
          end

          data[cookbook_artifact] = { url: cookbook_url, versions: versions }
        end

        return json_response(200, data)
      end
    end
  end
end
