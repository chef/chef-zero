require 'json'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /data
    class DataBagsEndpoint < RestListEndpoint
      def post(request)
        contents = request.body
        name = JSON.parse(contents, :create_additions => false)[identity_key]
        if name.nil?
          error(400, "Must specify '#{identity_key}' in JSON")
        elsif exists_data_dir?(request, ['data', name])
          error(409, "Object already exists")
        else
          data_store.create_dir(['data'], name, :recursive)
          json_response(201, {"uri" => "#{build_uri(request.base_uri, request.rest_path + [name])}"})
        end
      end
    end
  end
end
