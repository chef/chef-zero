require "ffi_yajl"
require "chef_zero/endpoints/rest_list_endpoint"

module ChefZero
  module Endpoints
    # /organizations/ORG/containers
    class ContainersEndpoint < RestListEndpoint
      def initialize(server)
        super(server, %w{id containername})
      end

      # create a container.
      # input: {"containername"=>"new-container", "containerpath"=>"/"}
      def post(request)
        data = parse_json(request.body)
        # if they don't match, id wins.
        container_name = data["id"] || data["containername"]
        container_path_suffix = data["containerpath"].split("/").reject { |o| o.empty? }
        create_data(request, request.rest_path, container_name, to_json({}), :create_dir)

        json_response(201, { uri: build_uri(request.base_uri, request.rest_path + container_path_suffix + [container_name]) })
      end
    end
  end
end
