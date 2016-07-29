require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /organizations/ORG/policies
    class PoliciesEndpoint < RestBase
      # GET /organizations/ORG/policies
      def get(request)
        response_data = {}
        policy_names = list_data(request)
        policy_names.each do |policy_name|
          policy_path = request.rest_path + [policy_name]
          policy_uri = build_uri(request.base_uri, policy_path)
          revisions = list_data(request, policy_path + ["revisions"])

          response_data[policy_name] = {
            uri: policy_uri,
            revisions: hashify_list(revisions),
          }
        end

        return json_response(200, response_data)
      end
    end
  end
end
