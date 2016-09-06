require "ffi_yajl"
require "chef_zero/endpoints/cookbooks_base"

module ChefZero
  module Endpoints
    # /environments/NAME/cookbooks/NAME
    class EnvironmentCookbookEndpoint < CookbooksBase
      def get(request)
        cookbook_name = request.rest_path[5]
        environment = FFI_Yajl::Parser.parse(get_data(request, request.rest_path[0..3]))
        constraints = environment["cookbook_versions"] || {}
        cookbook_versions = list_data(request, request.rest_path[0..1] + request.rest_path[4..5])
        if request.query_params["num_versions"] == "all"
          num_versions = nil
        elsif request.query_params["num_versions"]
          num_versions = request.query_params["num_versions"].to_i
        else
          num_versions = nil
        end
        json_response(200, format_cookbooks_list(request, { cookbook_name => cookbook_versions }, constraints, num_versions))
      end
    end
  end
end
