require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /verify_password
    class VerifyPasswordEndpoint < RestBase
      def post(request)
        request_json = JSON.parse(request.body, :create_additions => false)
        name = request_json['user_id_to_verify']
        password = request_json['password']
        user = get_data(request, request.rest_path[0..-2] + ['users', name], :nil)
        if !user
          raise RestErrorResponse.new(403, "Nonexistent user")
        end

        user = JSON.parse(user, :create_additions => false)
        json_response(200, { 'password_is_correct' => user['password'] == password })
      end
    end
  end
end
