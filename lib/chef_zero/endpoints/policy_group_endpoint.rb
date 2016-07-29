require "ffi_yajl"
require "chef_zero/rest_base"
require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /organizations/ORG/policy_groups/NAME
    class PolicyGroupEndpoint < RestBase

      # GET /organizations/ORG/policy_groups/NAME
      def get(request)
        data = {
          uri: build_uri(request.base_uri, request.rest_path),
          policies: get_policy_group_policies(request),
        }
        json_response(200, data)
      end

      # build a hash of {"some_policy_name"=>{"revision_id"=>"909c26701e291510eacdc6c06d626b9fa5350d25"}}
      def get_policy_group_policies(request)
        policies_revisions = {}

        policies_path = request.rest_path + ["policies"]
        policy_names = list_data(request, policies_path)
        policy_names.each do |policy_name|
          revision = parse_json(get_data(request, policies_path + [policy_name]))
          policies_revisions[policy_name] = { revision_id: revision }
        end

        policies_revisions
      end

      # DELETE /organizations/ORG/policy_groups/NAME
      def delete(request)
        policy_group_policies = get_policy_group_policies(request)
        delete_data_dir(request, nil, :recursive)

        data = {
          uri: build_uri(request.base_uri, request.rest_path),
          policies: policy_group_policies,
        }
        json_response(200, data)
      end
    end
  end
end
