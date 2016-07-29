require "ffi_yajl"
require "chef_zero/rest_base"
require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /organizations/ORG/policy_groups
    #
    # in the data store, this REST path actually stores the revision ID of ${policy_name} that's currently
    # associated with ${policy_group}.
    class PolicyGroupsEndpoint < RestBase
      # GET /organizations/ORG/policy_groups
      def get(request)
        # each policy group has policies and associated revisions under
        # /policy_groups/{group name}/policies/{policy name}.
        response_data = {}
        list_data(request).each do |group_name|
          group_path = request.rest_path + [group_name]
          policy_list = list_data(request, group_path + ["policies"])

          # build the list of policies with their revision ID associated with this policy group.
          policies = {}
          policy_list.each do |policy_name|
            revision_id = parse_json(get_data(request, group_path + ["policies", policy_name]))
            policies[policy_name] = { revision_id: revision_id }
          end

          response_data[group_name] = {
            uri: build_uri(request.base_uri, group_path),
          }
          response_data[group_name][:policies] = policies unless policies.empty?
        end

        json_response(200, response_data)
      end
    end
  end
end
