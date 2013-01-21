require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # Typical REST list endpoint (/roles or /data/BAG)
    class RestListEndpoint < RestBase
      def initialize(server, identity_key = 'name')
        super(server)
        @identity_key = identity_key
      end

      attr_reader :identity_key

      def get(request)
        # Get the result
        result_hash = {}
        get_data(request).keys.sort.each do |name|
          result_hash[name] = "#{build_uri(request.base_uri, request.rest_path + [name])}"
        end
        json_response(200, result_hash)
      end

      def post(request)
        container = get_data(request)
        contents = request.body
        key = get_key(contents)
        if key.nil?
          error(400, "Must specify '#{identity_key}' in JSON")
        elsif container[key]
          error(409, 'Object already exists')
        else
          container[key] = contents
          json_response(201, {'uri' => "#{build_uri(request.base_uri, request.rest_path + [key])}"})
        end
      end

      def get_key(contents)
        JSON.parse(contents, :create_additions => false)[identity_key]
      end
    end
  end
end
