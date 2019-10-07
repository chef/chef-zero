require "chef_zero/rest_base"
require "chef_zero/dist"

module ChefZero
  module Endpoints
    # /version
    class VersionEndpoint < RestBase
      def get(request)
        text_response(200, "#{ChefZero::Dist::CLIENT} #{ChefZero::VERSION}\n")
      end
    end
  end
end
