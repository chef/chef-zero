require "ffi_yajl"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /roles/NAME/environments
    class RoleEnvironmentsEndpoint < RestBase
      def get(request)
        role = FFI_Yajl::Parser.parse(get_data(request, request.rest_path[0..3]))
        json_response(200, [ "_default" ] + (role["env_run_lists"].keys || []))
      end
    end
  end
end
