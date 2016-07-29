require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /organizations/ORG/policies/NAME/revisions
    class PolicyRevisionsEndpoint < RestBase
      # POST /organizations/ORG/policies/NAME/revisions
      def post(request)
        policyfile_data = parse_json(request.body)
        create_data(request, request.rest_path, policyfile_data["revision_id"], request.body, :create_dir)
        return already_json_response(201, request.body)
      end
    end
  end
end
