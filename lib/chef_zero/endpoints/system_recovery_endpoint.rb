require "ffi_yajl"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /system_recovery
    class SystemRecoveryEndpoint < RestBase
      def post(request)
        request_json = FFI_Yajl::Parser.parse(request.body)
        name = request_json["username"]
        password = request_json["password"]
        user = get_data(request, request.rest_path[0..-2] + ["users", name], :nil)
        if !user
          raise RestErrorResponse.new(403, "Nonexistent user")
        end

        user = FFI_Yajl::Parser.parse(user)
        user = ChefData::DataNormalizer.normalize_user(user, name, [ "username" ], server.options[:osc_compat])
        if !user["recovery_authentication_enabled"]
          raise RestErrorResponse.new(403, "Only users with recovery_authentication_enabled=true may use /system_recovery to log in")
        end
        if user["password"] != password
          raise RestErrorResponse.new(401, "Incorrect password")
        end

        json_response(200, user)
      end
    end
  end
end
