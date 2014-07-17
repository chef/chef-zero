require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /system_recovery
    class SystemRecoveryEndpoint < RestBase
      def post(request)
        request_json = JSON.parse(request.body, :create_additions => false)
        name = request_json['username']
        password = request_json['password']
        user = get_data(request, request.rest_path[0..-2] + ['users', name])
        user = JSON.parse(user, :create_additions => false)
        user = DataNormalizer.normalize_user(user, name)
        if !user['recovery_authentication_enabled']
          raise RestErrorResponse.new(403, "Only users with recovery_authentication_enabled=true may use /system_recovery to log in")
        end
        if user['password'] != password
          raise RestErrorResponse.new(401, "Incorrect password")
        end

        json_response(200, user)
      end
    end
  end
end
