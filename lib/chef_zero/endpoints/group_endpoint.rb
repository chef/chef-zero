require "ffi_yajl" unless defined?(FFI_Yajl)
require_relative "rest_object_endpoint"
require_relative "../chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /organizations/ORG/groups/NAME
    class GroupEndpoint < RestObjectEndpoint
      def initialize(server)
        super(server, %w{id groupname})
      end

      def populate_defaults(request, response_json)
        group = FFI_Yajl::Parser.parse(response_json)
        group = ChefData::DataNormalizer.normalize_group(group, request.rest_path[3], request.rest_path[1])
        FFI_Yajl::Encoder.encode(group, pretty: true)
      end
    end
  end
end
