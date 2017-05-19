require "ffi_yajl"
require "chef_zero/endpoints/rest_object_endpoint"
require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /nodes/ID
    class NodeEndpoint < RestObjectEndpoint
      def put(request)
        data = parse_json(request.body)

        if data.has_key?("policy_name") && policy_name_invalid?(data["policy_name"])
          return error(400, "Field 'policy_name' invalid", :pretty => false)
        end

        if data.has_key?("policy_group") && policy_name_invalid?(data["policy_group"])
          return error(400, "Field 'policy_group' invalid", :pretty => false)
        end

        super(request)
      end

      def head(request)
        head_request(request)
      end

      def populate_defaults(request, response_json)
        node = FFI_Yajl::Parser.parse(response_json)
        node = ChefData::DataNormalizer.normalize_node(node, request.rest_path[3])
        FFI_Yajl::Encoder.encode(node, :pretty => true)
      end
    end
  end
end
