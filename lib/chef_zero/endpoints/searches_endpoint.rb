require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /search
    class SearchesEndpoint < RestBase
      def get(request)
        # Get the result
        result_hash = {}
        indices = (%w{client environment node role} + data_store.list(request.rest_path[0..1] + ["data"])).sort
        indices.each do |index|
          result_hash[index] = build_uri(request.base_uri, request.rest_path + [index])
        end
        json_response(200, result_hash)
      end
    end
  end
end
