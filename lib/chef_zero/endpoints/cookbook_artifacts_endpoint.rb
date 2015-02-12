require 'chef_zero/endpoints/cookbooks_base'

module ChefZero
  module Endpoints
    # /cookbook_artifacts
    class CookbookArtifactsEndpoint < CookbooksBase
      def get(request)
        if request.query_params['num_versions'] == 'all'
          num_versions = nil
        elsif request.query_params['num_versions']
          num_versions = request.query_params['num_versions'].to_i
        else
          num_versions = 1
        end
        json_response(200, format_cookbooks_list(request, all_cookbooks_list(request), {}, num_versions))
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
