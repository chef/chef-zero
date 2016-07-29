require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /organizations/ORG/policies/NAME/revisions/REVISION
    class PolicyRevisionEndpoint < RestBase
      # GET /organizations/ORG/policies/NAME/revisions/REVISION
      def get(request)
        data = parse_json(get_data(request))
        data = ChefData::DataNormalizer.normalize_policy(data, request.rest_path[3], request.rest_path[5])
        return json_response(200, data)
      end

      # DELETE /organizations/ORG/policies/NAME/revisions/REVISION
      def delete(request)
        policyfile_data = parse_json(get_data(request))
        policyfile_data = ChefData::DataNormalizer.normalize_policy(policyfile_data, request.rest_path[3], request.rest_path[5])
        delete_data(request)
        return json_response(200, policyfile_data)
      end
    end
  end
end
