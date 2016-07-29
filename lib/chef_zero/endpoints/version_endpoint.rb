require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /version
    class VersionEndpoint < RestBase
      def get(request)
        text_response(200, "chef-zero #{ChefZero::VERSION}\n")
      end
    end
  end
end
