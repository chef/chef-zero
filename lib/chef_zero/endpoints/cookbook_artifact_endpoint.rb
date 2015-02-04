require 'chef_zero/endpoints/cookbooks_base'

module ChefZero
  module Endpoints
    # /cookbook_artifacts/NAME
    class CookbookArtifactEndpoint < CookbooksBase
      def get(request)
        filter = request.rest_path[3]
        case filter
        when '_latest'
          result = {}
          filter_cookbooks(all_cookbooks_list(request), {}, 1) do |name, versions|
            if versions.size > 0
              result[name] = build_uri(request.base_uri, request.rest_path[0..1] + ['cookbook_artifacts', name, versions[0]])
            end
          end
          json_response(200, result)
        when '_recipes'
          result = []
          filter_cookbooks(all_cookbooks_list(request), {}, 1) do |name, versions|
            if versions.size > 0
              cookbook = FFI_Yajl::Parser.parse(get_data(request, request.rest_path[0..1] + ['cookbook_artifacts', name, versions[0]]), :create_additions => false)
              result += recipe_names(name, cookbook)
            end
          end
          json_response(200, result.sort)
        else
          cookbook_list = { filter => list_data(request, request.rest_path) }
          json_response(200, format_cookbooks_list(request, cookbook_list))
        end
      end

      def latest_version(versions)
        sorted = versions.sort_by { |version| Gem::Version.new(version.dup) }
        sorted[-1]
      end

      ## CookbooksBase Overrides
      # Methods here override behavior in CookbooksBase that is otherwise
      # hard-coded to 'cookbooks'

      def format_cookbooks_list(request, cookbooks_list, constraints = {}, num_versions = nil)
        results = {}
        filter_cookbooks(cookbooks_list, constraints, num_versions) do |name, versions|
          versions_list = versions.map do |version|
            {
              'url' => build_uri(request.base_uri, request.rest_path[0..1] + ['cookbook_artifacts', name, version]),
              'version' => version
            }
          end
          results[name] = {
            'url' => build_uri(request.base_uri, request.rest_path[0..1] + ['cookbook_artifacts', name]),
            'versions' => versions_list
          }
        end
        results
      end

      def all_cookbooks_list(request)
        result = {}
        # Race conditions exist here (if someone deletes while listing).  I don't care.
        data_store.list(request.rest_path[0..1] + ['cookbook_artifacts']).each do |name|
          result[name] = data_store.list(request.rest_path[0..1] + ['cookbook_artifacts', name])
        end
        result
      end
    end
  end
end
