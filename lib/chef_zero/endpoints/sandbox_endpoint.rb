require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /sandboxes/ID
    class SandboxEndpoint < RestBase
      def put(request)
        existing_sandbox = get_data(request, request.rest_path)
        data['sandboxes'].delete(request.rest_path[1])
        time_str = existing_sandbox[:create_time].strftime('%Y-%m-%dT%H:%M:%S%z')
        time_str = "#{time_str[0..21]}:#{time_str[22..23]}"
        json_response(200, {
          :guid => request.rest_path[1],
          :name => request.rest_path[1],
          :checksums => existing_sandbox[:checksums],
          :create_time => time_str,
          :is_completed => true
        })
      end
    end
  end
end
