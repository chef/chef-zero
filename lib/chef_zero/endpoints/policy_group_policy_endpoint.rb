require "ffi_yajl"
require "chef_zero/rest_base"
require "chef_zero/chef_data/data_normalizer"

module ChefZero
  module Endpoints
    # /organizations/ORG/policy_groups/GROUP/policies/NAME
    #
    # in the data store, this REST path actually stores the revision ID of ${policy_name} that's currently
    # associated with ${policy_group}.
    class PolicyGroupPolicyEndpoint < RestBase

      # GET /organizations/ORG/policy_groups/GROUP/policies/NAME
      def get(request)
        policy_name = request.rest_path[5]

        # fetch /organizations/{organization}/policies/{policy_name}/revisions/{revision_id}
        revision_id = parse_json(get_data(request))
        result = get_data(request, request.rest_path[0..1] +
                                   ["policies", policy_name, "revisions", revision_id])
        result = ChefData::DataNormalizer.normalize_policy(parse_json(result), policy_name, revision_id)
        json_response(200, result)
      end

      # Create or update the policy document for the given policy group and policy name. If no policy group
      # with the given name exists, it will be created. If no policy with the given revision_id exists, it
      # will be created from the document in the request body. If a policy with that revision_id exists, the
      # Chef Server simply associates that revision id with the given policy group. When successful, the
      # document that was created or updated is returned.

      ## MANDATORY FIELDS AND FORMATS
      # * `revision_id`: String; Must be < 255 chars, matches /^[\-[:alnum:]_\.\:]+$/
      # * `name`: String; Must match name in URI; Must be <= 255 chars, matches /^[\-[:alnum:]_\.\:]+$/
      # * `run_list`: Array
      # * `run_list[i]`: Fully Qualified Recipe Run List Item
      # * `cookbook_locks`: JSON Object
      # * `cookbook_locks(key)`: CookbookName
      # * `cookbook_locks[item]`: JSON Object, mandatory keys: "identifier", "dotted_decimal_identifier"
      # * `cookbook_locks[item]["identifier"]`: varchar(255) ?
      # * `cookbook_locks[item]["dotted_decimal_identifier"]` ChefCompatibleVersionNumber

      # PUT /organizations/ORG/policy_groups/GROUP/policies/NAME
      def put(request)
        policyfile_data = parse_json(request.body)
        policy_name = request.rest_path[5]
        revision_id = policyfile_data["revision_id"]

        # If the policy revision being submitted does not exist, create it.
        # Storage: /organizations/ORG/policies/POLICY/revisions/REVISION
        policyfile_path = request.rest_path[0..1] + ["policies", policy_name, "revisions", revision_id]
        if !exists_data?(request, policyfile_path)
          create_data(request, policyfile_path[0..-2], revision_id, request.body, :create_dir)
        end

        # if named policy exists and the given revision ID exists, associate the revision ID with the policy
        # group.
        # Storage: /organizations/ORG/policies/POLICY/revisions/REVISION
        response_code = exists_data?(request) ? 200 : 201
        set_data(request, nil, to_json(revision_id), :create, :create_dir)

        already_json_response(response_code, request.body)
      end

      # DELETE /organizations/ORG/policy_groups/GROUP/policies/NAME
      def delete(request)
        # Save the existing association.
        current_revision_id = parse_json(get_data(request))

        # delete the association.
        delete_data(request)

        # return the full policy document at the no-longer-associated revision.
        policy_name = request.rest_path[5]
        policy_path = request.rest_path[0..1] + ["policies", policy_name,
                                                 "revisions", current_revision_id]

        full_policy_doc = parse_json(get_data(request, policy_path))
        full_policy_doc = ChefData::DataNormalizer.normalize_policy(full_policy_doc, policy_name, current_revision_id)
        return json_response(200, full_policy_doc)
      end
    end
  end
end
