require "chef_zero/endpoints/cookbooks_base"

module ChefZero
  module Endpoints
    # /cookbooks
    class CookbooksEndpoint < CookbooksBase
      def get(request)
        if request.query_params["num_versions"] == "all"
          num_versions = nil
        elsif request.query_params["num_versions"]
          num_versions = request.query_params["num_versions"].to_i
        else
          num_versions = 1
        end
        json_response(200, format_cookbooks_list(request, all_cookbooks_list(request), {}, num_versions))
      end
    end
  end
end
