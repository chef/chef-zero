require "chef_zero/rest_base"
require "chef_zero/endpoints/actor_keys_endpoint"

module ChefZero
  module Endpoints
    # GET /organizations/ORG/users/USER/keys/NAME
    class OrganizationUserKeyEndpoint < RestBase
      def get(request)
        # 404 if not a member of the org
        get_data(request, request.rest_path[0..3])
        # Just use the /users/USER/keys endpoint
        request.rest_path = request.rest_path[2..-1]
        ActorKeyEndpoint.new(server).get(request)
      end
    end
  end
end
