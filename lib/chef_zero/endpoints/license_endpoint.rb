require "ffi_yajl" unless defined?(FFI_Yajl)
require_relative "../rest_base"

module ChefZero
  module Endpoints
    # /license
    class LicenseEndpoint < RestBase
      MAX_NODE_COUNT = 25

      def get(request)
        node_count = 0
        list_data(request, [ "organizations" ]).each do |orgname|
          node_count += list_data(request, [ "organizations", orgname, "nodes" ]).size
        end

        json_response(200, {
          "limit_exceeded" => (node_count > MAX_NODE_COUNT) ? true : false,
          "node_license" => MAX_NODE_COUNT,
          "node_count" => node_count,
          "upgrade_url" => "https://blah.com",
        })
      end
    end
  end
end
