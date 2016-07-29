require "ffi_yajl"
require "chef_zero/rest_base"
require "uuidtools"

module ChefZero
  module Endpoints
    # /organizations/NAME/nodes/NAME/_identifiers
    class NodeIdentifiersEndpoint < RestBase
      def get(request)
        if get_data(request, request.rest_path[0..3])
          result = {
            :id => UUIDTools::UUID.parse_raw(request.rest_path[0..4].to_s).to_s.delete("-"),
            :authz_id => "0" * 32,
            :org_id => UUIDTools::UUID.parse_raw(request.rest_path[0..1].to_s).to_s.delete("-") }
          json_response(200, result)
        else
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
        end
      end
    end
  end
end
