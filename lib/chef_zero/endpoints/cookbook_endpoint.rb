require 'chef_zero/endpoints/cookbooks_base'
require 'solve'

module ChefZero
  module Endpoints
    # /cookbooks/NAME
    class CookbookEndpoint < CookbooksBase
      def get(request)
        filter = request.rest_path[1]
        case filter
        when '_latest'
          result = {}
          filter_cookbooks(data['cookbooks'], {}, 1) do |name, versions|
            if versions.size > 0
              result[name] = build_uri(request.base_uri, ['cookbooks', name, versions[0]])
            end
          end
          json_response(200, result)
        when '_recipes'
          result = []
          filter_cookbooks(data['cookbooks'], {}, 1) do |name, versions|
            if versions.size > 0
              cookbook = JSON.parse(data['cookbooks'][name][versions[0]], :create_additions => false)
              result += recipe_names(name, cookbook)
            end
          end
          json_response(200, result.sort)
        else
          cookbook_list = { filter => get_data(request, request.rest_path) }
          json_response(200, format_cookbooks_list(request, cookbook_list))
        end
      end

      def latest_version(versions)
        sorted = versions.sort_by { |version| Solve::Version.new(version) }
        sorted[-1]
      end
    end
  end
end
