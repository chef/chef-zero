require 'json'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /data
    class DataBagsEndpoint < RestListEndpoint
      def post(request)
        container = get_data(request)
        contents = request.body
        name = JSON.parse(contents, :create_additions => false)[identity_key]
        if container[name]
          error(409, "Object already exists")
        else
          container[name] = {}
          json_response(201, {"uri" => "#{build_uri(request.base_uri, request.rest_path + [name])}"})
        end
      end
    end
  end
end
