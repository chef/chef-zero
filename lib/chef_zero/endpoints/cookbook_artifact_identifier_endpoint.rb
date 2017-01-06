require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    class CookbookArtifactIdentifierEndpoint < ChefZero::Endpoints::CookbookVersionEndpoint
      # these endpoints are almost, but not quite, not entirely unlike the corresponding /cookbooks endpoints.
      # it could all be refactored for maximum reuse, but they're short REST methods with well-defined
      # behavioral specs (pedant), so there's not a huge benefit.

      # GET /organizations/ORG/cookbook_artifacts/NAME/IDENTIFIER
      def get(request)
        cookbook_data = normalize(request, get_data(request))
        return json_response(200, cookbook_data)
      end

      # PUT /organizations/ORG/cookbook_artifacts/COOKBOOK/IDENTIFIER
      def put(request)
        if exists_data?(request)
          return error(409, "Cookbooks cannot be modified, and a cookbook with this identifier already exists.")
        end

        cb_data = normalize(request, request.body)
        set_data(request, nil, to_json(cb_data), :create_dir)

        return already_json_response(201, request.body)
      end

      # DELETE /organizations/ORG/cookbook_artifacts/COOKBOOK/IDENTIFIER
      def delete(request)
        begin
          doomed_cookbook_json = get_data(request)
          identified_cookbook_data = normalize(request, doomed_cookbook_json)
          delete_data(request)

          # go through the recipes and delete stuff in the file store.
          hoover_unused_checksums(get_checksums(doomed_cookbook_json), request)

          # if this was the last revision, delete the directory so future requests will 404, instead of
          # returning 200 with an empty list.
          # Last one out turns out the lights: delete /organizations/ORG/cookbooks/COOKBOOK if it no longer has versions
          cookbook_path = request.rest_path[0..3]
          if exists_data_dir?(request, cookbook_path) && list_data(request, cookbook_path).size == 0
            delete_data_dir(request, cookbook_path)
          end

          json_response(200, identified_cookbook_data)
        rescue RestErrorResponse => ex
          if ex.response_code == 404
            error(404, "not_found")
          else
            raise
          end
        end
      end

      private

      def make_file_store_path(rest_path, recipe)
        rest_path.first(2) + ["file_store", "checksums", recipe["checksum"]]
      end

      def normalize(request, cookbook_artifact_data)
        cookbook = parse_json(cookbook_artifact_data)
        ChefData::DataNormalizer.normalize_cookbook(self, request.rest_path[0..1],
                                                    cookbook, request.rest_path[3], request.rest_path[4],
                                                    request.base_uri, request.method, true, api_version: request.api_version)
      end
    end
  end
end
