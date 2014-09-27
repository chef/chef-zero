require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # Typical REST list endpoint (/roles or /data/BAG)
    class RestListEndpoint < RestBase
      def initialize(server, identity_keys = [ 'name' ])
        super(server)
        identity_keys = [ identity_keys ] if identity_keys.is_a?(String)
        @identity_keys = identity_keys
      end

      attr_reader :identity_keys

      def get(request)
        # Get the result
        result_hash = {}
        list_data(request).sort.each do |name|
          result_hash[name] = "#{build_uri(request.base_uri, request.rest_path + [name])}"
        end
        json_response(200, result_hash)
      end

      def post(request)
        contents = request.body
        key = get_key(contents)
        if key.nil?
          error(400, "Must specify #{identity_keys.map { |k| k.inspect }.join(' or ')} in JSON")
        else
          create_data(request, request.rest_path, key, contents)
          json_response(201, {'uri' => "#{build_uri(request.base_uri, request.rest_path + [key])}"})
        end
      end

      def get_key(contents)
        json = FFI_Yajl::Parser.parse(contents, :create_additions => false)
        identity_keys.map { |k| json[k] }.select { |v| v }.first
      end
    end
  end
end
