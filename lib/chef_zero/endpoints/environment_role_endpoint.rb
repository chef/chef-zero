require "ffi_yajl"
require "chef_zero/endpoints/cookbooks_base"

module ChefZero
  module Endpoints
    # /environments/NAME/roles/NAME
    # /roles/NAME/environments/NAME
    class EnvironmentRoleEndpoint < CookbooksBase
      def get(request)
        # 404 if environment does not exist
        if request.rest_path[2] == "environments"
          environment_path = request.rest_path[0..1] + request.rest_path[2..3]
          role_path = request.rest_path[0..1] + request.rest_path[4..5]
        else
          environment_path = request.rest_path[0..1] + request.rest_path[4..5]
          role_path = request.rest_path[0..1] + request.rest_path[2..3]
        end
        # Verify that the environment exists
        get_data(request, environment_path)

        role = FFI_Yajl::Parser.parse(get_data(request, role_path))
        environment_name = environment_path[3]
        if environment_name == "_default"
          run_list = role["run_list"]
        else
          if role["env_run_lists"]
            run_list = role["env_run_lists"][environment_name]
          else
            run_list = nil
          end
        end
        json_response(200, { "run_list" => run_list })
      end
    end
  end
end
