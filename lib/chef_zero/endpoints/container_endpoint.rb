require "ffi_yajl" unless defined?(FFI_Yajl)
require_relative "rest_object_endpoint"
require_relative "../chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /organizations/ORG/containers/NAME
    class ContainerEndpoint < RestObjectEndpoint
      def initialize(server)
        super(server, %w{id containername})
      end

      undef_method(:put)

      def populate_defaults(request, response_json)
        container = FFI_Yajl::Parser.parse(response_json)
        container = ChefData::DataNormalizer.normalize_container(container, request.rest_path[3])
        FFI_Yajl::Encoder.encode(container, pretty: true)
      end
    end
  end
end
