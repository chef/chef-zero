require "ffi_yajl"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /organizations/ORG/users/NAME
    class OrganizationUserEndpoint < RestBase
      def get(request)
        username = request.rest_path[3]
        get_data(request) # 404 if user is not in org
        user = get_data(request, [ "users", username ])
        user = FFI_Yajl::Parser.parse(user)
        json_response(200, ChefData::DataNormalizer.normalize_user(user, username, ["username"], server.options[:osc_compat], request.method))
      end

      def delete(request)
        user = get_data(request)
        delete_data(request)
        user = FFI_Yajl::Parser.parse(user)
        json_response(200, ChefData::DataNormalizer.normalize_user(user, request.rest_path[3], ["username"], server.options[:osc_compat]))
      end

      # Note: post to a named org user is not permitted, alllow invalid method handling (405)
    end
  end
end
