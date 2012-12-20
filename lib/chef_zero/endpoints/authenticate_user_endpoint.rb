require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /authenticate_user
    class AuthenticateUserEndpoint < RestBase
      def post(request)
        request_json = JSON.parse(request.body, :create_additions => false)
        name = request_json['name']
        password = request_json['password']
        user = data['users'][name]
        verified = user && JSON.parse(user, :create_additions => false)['password'] == password
        json_response(200, {
          'name' => name,
          'verified' => !!verified
        })
      end
    end
  end
end
