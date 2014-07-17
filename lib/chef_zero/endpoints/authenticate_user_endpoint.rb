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
        begin
          user = data_store.get(request.rest_path[0..-2] + ['users', name])
        rescue ChefZero::DataStore::DataNotFoundError
          raise RestErrorResponse.new(401, "Bad username or password")
        end
        user = JSON.parse(user, :create_additions => false)
        user = DataNormalizer.normalize_user(user, name)
        if user['password'] != password
          raise RestErrorResponse.new(401, "Bad username or password")
        end
        json_response(200, {
          'status' => 'linked',
          'user' => user
        })
      end
    end
  end
end
