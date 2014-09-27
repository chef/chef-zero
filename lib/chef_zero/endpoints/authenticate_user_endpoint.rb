require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /authenticate_user
    class AuthenticateUserEndpoint < RestBase
      def post(request)
        request_json = FFI_Yajl::Parser.parse(request.body, :create_additions => false)
        name = request_json['username']
        password = request_json['password']
        begin
          user = data_store.get(['users', name])
        rescue ChefZero::DataStore::DataNotFoundError
          raise RestErrorResponse.new(401, "Bad username or password")
        end
        user = FFI_Yajl::Parser.parse(user, :create_additions => false)
        user = ChefData::DataNormalizer.normalize_user(user, name, [ 'username' ], server.options[:osc_compat])
        if user['password'] != password
          raise RestErrorResponse.new(401, "Bad username or password")
        end
        # Include only particular user data in the response
        user.keep_if { |key,value| %w(first_name last_name display_name email username).include?(key) }
        json_response(200, {
          'status' => 'linked',
          'user' => user
        })
      end
    end
  end
end
