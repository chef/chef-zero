require 'json'
require 'chef_zero/endpoints/rest_list_endpoint'

module ChefZero
  module Endpoints
    # /data
    class DataBagsEndpoint < RestListEndpoint
      def post(request)
        contents = request.body
        json = JSON.parse(contents, :create_additions => false)
        name = identity_keys.map { |k| json[k] }.select { |v| v }.first
        if name.nil?
          error(400, "Must specify #{identity_keys.map { |k| k.inspect }.join(' or ')} in JSON")
        elsif exists_data_dir?(request, request.rest_path[0..1] + ['data', name])
          error(409, "Object already exists")
        else
          data_store.create_dir(request.rest_path[0..1] + ['data'], name, :recursive)
          json_response(201, {"uri" => "#{build_uri(request.base_uri, request.rest_path + [name])}"})
        end
      end
    end
  end
end
