require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /server_api_version
    class ServerAPIVersionEndpoint < RestBase
      def get(request)
        json_response(200, {"min_api_version"=>MIN_API_VERSION, "max_api_version"=>MAX_API_VERSION})
      end
    end
  end
end
