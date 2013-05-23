require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /sandboxes/ID
    class SandboxEndpoint < RestBase
      def put(request)
        existing_sandbox = JSON.parse(get_data(request), :create_additions => false)
        delete_data(request)
        json_response(200, {
          :guid => request.rest_path[1],
          :name => request.rest_path[1],
          :checksums => existing_sandbox[:checksums],
          :create_time => existing_sandbox[:create_time],
          :is_completed => true
        })
      end
    end
  end
end
