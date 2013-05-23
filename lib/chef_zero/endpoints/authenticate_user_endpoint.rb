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
          user = data_store.get(['users', name])
          verified = JSON.parse(user, :create_additions => false)['password'] == password
        rescue DataStore::DataNotFoundError
          verified = false
        end
        json_response(200, {
          'name' => name,
          'verified' => !!verified
        })
      end
    end
  end
end
