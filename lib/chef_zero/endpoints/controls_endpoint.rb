require "chef_zero/dist"
module ChefZero
  module Endpoints
    # /organizations/ORG/controls
    class ControlsEndpoint < RestBase
      # ours is not to wonder why; ours is but to make the pedant specs pass.
      def get(request)
        error(410, "Server says 410, #{ChefZero::Dist::CLIENT} says 410.")
      end

      def post(request)
        error(410, "Server says 410, #{ChefZero::Dist::CLIENT} says 410.")
      end
    end
  end
end
