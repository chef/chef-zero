require 'chef_zero/endpoints/cookbooks_base'

module ChefZero
  module Endpoints
    # /cookbooks
    class CookbooksEndpoint < CookbooksBase
      def get(request)
        json_response(200, format_cookbooks_list(request, data['cookbooks']))
      end
    end
  end
end
