require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # GET /organizations/ORG/users/USER/keys/default
    class OrganizationUserDefaultKeyEndpoint < RestBase
      def get(request)
        # 404 if it doesn't exist
        get_data(request, request.rest_path[0..3])
        # Just use the /users/USER/keys/default endpoint
        request.rest_path = request.rest_path[2..-1]
        ActorDefaultKeyEndpoint.new(server).get(request)
      end
    end
  end
end
