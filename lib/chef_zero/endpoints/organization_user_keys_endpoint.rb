require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # GET /organizations/ORG/users/USER/keys
    class OrganizationUserKeysEndpoint < RestBase
      def get(request)
        # 404 if it doesn't exist
        get_data(request, request.rest_path[0..3])
        # Just use the /users/USER/keys/key endpoint
        original_path = request.rest_path
        request.rest_path = request.rest_path[2..-1]
        ActorKeysEndpoint.new(server).get(request, original_path)
      end
    end
  end
end
