require "ffi_yajl"
require "chef_zero/endpoints/rest_object_endpoint"
require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /universe
    class UniverseEndpoint < CookbooksBase

      def get(request)
        json_response(200, format_universe_list(request, all_cookbooks_list(request)))
      end
    end
  end
end
