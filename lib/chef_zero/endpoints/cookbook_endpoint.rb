require 'chef_zero/endpoints/cookbooks_base'

module ChefZero
  module Endpoints
    # /cookbooks/NAME
    class CookbookEndpoint < CookbooksBase
      def get(request)
        filter = request.rest_path[3]
        case filter
        when '_latest'
          result = {}
          filter_cookbooks(all_cookbooks_list(request), {}, 1) do |name, versions|
            if versions.size > 0
              result[name] = build_uri(request.base_uri, request.rest_path[0..1] + ['cookbooks', name, versions[0]])
            end
          end
          json_response(200, result)
        when '_recipes'
          result = []
          filter_cookbooks(all_cookbooks_list(request), {}, 1) do |name, versions|
            if versions.size > 0
              cookbook = FFI_Yajl::Parser.parse(get_data(request, request.rest_path[0..1] + ['cookbooks', name, versions[0]]), :create_additions => false)
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
    end
  end
end
