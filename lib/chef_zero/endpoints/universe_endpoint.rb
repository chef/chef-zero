require "ffi_yajl" unless defined?(FFI_Yajl)
require_relative "rest_object_endpoint"
require_relative "../chef_data/data_normalizer"

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
