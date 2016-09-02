require "ffi_yajl"
require "chef_zero/endpoints/cookbooks_base"

module ChefZero
  module Endpoints
    # /environments/NAME/cookbooks
    class EnvironmentCookbooksEndpoint < CookbooksBase
      def get(request)
        environment = FFI_Yajl::Parser.parse(get_data(request, request.rest_path[0..3]))
        constraints = environment["cookbook_versions"] || {}
        if request.query_params["num_versions"] == "all"
          num_versions = nil
        elsif request.query_params["num_versions"]
          num_versions = request.query_params["num_versions"].to_i
        else
          num_versions = 1
        end
        json_response(200, format_cookbooks_list(request, all_cookbooks_list(request), constraints, num_versions))
      end
    end
  end
end
