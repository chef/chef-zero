require 'ffi_yajl'
require 'chef_zero/rest_base'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /organizations/{organization}/policy_groups/{policy_group}/policies/{policy_name}
    # GET / PUT / DELETE
    #
    # in the data store, this REST path actually stores the revision ID of ${policy_name} that's currently
    # associated with ${policy_group}.
    class OrganizationPolicyGroupsEndpoint < RestBase

      def fetch_uri_params(request)
        {
          org_name: request.rest_path[1],
          policy_group_name: request.rest_path[3],
          policy_name: request.rest_path[5]
        }
      end

      # Either return all the policy groups with URIs and list of revisions, or...
      # Return the policy document for the given policy group and policy name.
      def get(request)

        # vanilla /policy_groups.
        if request.rest_path.last == "policy_groups"
          policy_group_names = list_data_or_else(request, nil, [])
          puts "List #{request.rest_path}: #{policy_group_names}"
          # no policy groups, so sad.
          if policy_group_names.size == 0
            return already_json_response(200, '{}')
          else

            response_data = {}
            # each policy group has policies and associated revisions under
            # /policy_groups/{group name}/policies/{policy name}.
            policy_group_names.each do |group_name|

              response_data[group_name] = {
                uri: build_uri(request.base_uri, request.rest_path + [group_name]),
                policies: {}
              }

              policy_group_path = request.rest_path + [group_name]
              policy_group_policies_path = policy_group_path + ["policies"]
              policy_list = list_data(request, policy_group_policies_path)

              # build the list of policies with their revision ID associated with this policy group.
              policy_list.each do |policy_name|
                policy_group_policy_path = policy_group_policies_path + [policy_name]
                revision_id = get_data_or_else(request, policy_group_policy_path, "no revision ID found")
                response_data[group_name][:policies][policy_name] = {
                  revision_id: revision_id
                }
              end

              response_data[group_name].delete(:policies) if response_data[group_name][:policies].size == 0
            end

            return json_response(200, response_data)
          end    # if policy_groups.size > 0
        end    # end /policy_groups

        # /policy_groups/{policy_group}
        if request.rest_path.last(2).first == "policy_groups"
          data = {
            uri: build_uri(request.base_uri, request.rest_path),
            policies: get_policy_group_policies(request)
          }
          return json_response(200, data)
        end

        # /policy_groups/{policy_group}/policies/{policy_name}
        if request.rest_path.last(2).first == "policies"
          uri_params = fetch_uri_params(request)

          # fetch /organizations/{organization}/policies/{policy_name}/revisions/{revision_id}
          revision_id = parse_json(get_data(request))
          result = get_data(request, ["organizations", uri_params[:org_name], "policies",
                            uri_params[:policy_name], "revisions", revision_id], :nil)
          result = ChefData::DataNormalizer.normalize_policy(parse_json(result), uri_params[:policy_name], revision_id)
          return json_response(200, result)
        end
      end    # end get()

      # Create or update the policy document for the given policy group and policy name. If no policy group
      # with the given name exists, it will be created. If no policy with the given revision_id exists, it
      # will be created from the document in the request body. If a policy with that revision_id exists, the
      # Chef Server simply associates that revision id with the given policy group. When successful, the
      # document that was created or updated is returned.

      # build a hash of {"some_policy_name"=>{"revision_id"=>"909c26701e291510eacdc6c06d626b9fa5350d25"}}
      def get_policy_group_policies(request)
        policies_revisions = {}

        policies_path = request.rest_path + ["policies"]
        policy_names = list_data(request, policies_path)
        policy_names.each do |policy_name|
          revision = parse_json(get_data(request, policies_path + [policy_name]))
          policies_revisions[policy_name] = { revision_id: revision}
        end

        policies_revisions
      end

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


      def cookbook_locks_valid?(cookbook_locks)
        if !cookbook_locks.is_a?(Hash)
          return [false, "Field 'cookbook_locks' invalid"]
        end

        cookbook_locks.each do |name, lock_data|
          if !lock_data.is_a?(Hash)
            return [false, "Field 'cookbook_locks' invalid"]
          end

          if !lock_data.has_key?("identifier")
            return [false, "Field 'identifier' missing"]
          end

          if lock_data["identifier"].length > 255
            return [false, "Field 'identifier' invalid"]
          end

          if lock_data.has_key?("dotted_decimal_identifier") &&
             lock_data["dotted_decimal_identifier"] !~ /\d+\.\d+\.\d+/
            return [false, "Field 'dotted_decimal_identifier' is not a valid version"]
          end
        end
        return [true, "no error to return"]
      end

      def validate_policyfile(policyfile_data)
        if !policyfile_data.has_key?("revision_id")
          return [false, "Field 'revision_id' missing"]
        elsif policyfile_data["revision_id"] !~ /^[\-[:alnum:]_\.\:]{1,255}$/
          return [false, "Field 'revision_id' invalid"]
        end

        if !policyfile_data.has_key?("name")
          return [false, "Field 'name' missing"]
        elsif policyfile_data["name"] !~ /^[\-[:alnum:]_\.\:]{1,255}$/
          return [false, "Field 'name' invalid"]
        end

        if !policyfile_data.has_key?("run_list")
          return [false, "Field 'run_list' missing"]
        elsif !(policyfile_data["run_list"].is_a?(Array) &&
                policyfile_data["run_list"].all? { |r| r =~ /\Arecipe\[[^\s]+::[^\s]+\]\Z/ })
          return [false, "Field 'run_list' is not a valid run list"]
        end

        if !policyfile_data.has_key?("cookbook_locks")
          return [false, "Field 'cookbook_locks' missing"]
        else
          # change this logic if there are more validations after this.
          return cookbook_locks_valid?(policyfile_data["cookbook_locks"])
        end

        return [true, "no error to return"]
      end

      def put(request)

        # validate request body.
        policyfile_data = parse_json(request.body)

        is_valid, error_msg = validate_policyfile(policyfile_data)
        if !is_valid
          return error(400, error_msg)
        end

        if request.rest_path.last != policyfile_data["name"]
          return error(400, "Field 'name' invalid : #{request.rest_path.last} does not match #{policyfile_data["name"]}")
        end

        uri_params = fetch_uri_params(request)
        org_path = request.rest_path.first(2)


        new_policyfile_data = parse_json( request.body )

        # get the current list of revisions of this policyfile.
        policyfile_path = request.rest_path[0..1] + ["policies", uri_params[:policy_name]]

        policy_revisions = list_data_or_else(request, policyfile_path + ["revisions"], [])

        # if the given policy+revision doesn't exist, create it..
        if !policy_revisions.include?(new_policyfile_data["revision_id"])
          new_revision_path = policyfile_path +["revisions", new_policyfile_data["revision_id"]]
          set_data(request, new_revision_path, request.body, *set_opts)
          created_policy = true
        end

        no_revision_set = "no revision ID set"

        # this request's data path just stores the revision ID currently associated with the policy group.
        existing_revision_id = get_data_or_else(request, nil, no_revision_set)

        # if named policy exists and the given revision ID exists, associate the revision ID with the policy
        # group.
        if existing_revision_id != new_policyfile_data["revision_id"]
          set_data(request, nil, to_json(new_policyfile_data["revision_id"]), *set_opts)
          updated_association = true
        end

        code = (existing_revision_id == no_revision_set) ? 201 : 200

        return already_json_response(code, request.body)
      end

      def delete(request)
        # /policy_groups/{policy_group}
        if request.rest_path.last(2).first == "policy_groups"

          policy_group_policies = get_policy_group_policies(request)

          if exists_data_dir?(request, request.rest_path + ["policies"])
            delete_data_dir(request, request.rest_path + ["policies"], :recursive)
          end

          data = {
            uri: build_uri(request.base_uri, request.rest_path),
            policies: policy_group_policies
          }
          return json_response(200, data)
        end

        # "/policy_groups/some_policy_group/policies/some_policy_name"
        if request.rest_path.last(2).first == "policies"
          current_revision_id = parse_json(get_data(request))

          # delete the association.
          delete_data(request)

          # return the full policy document at the no-longer-associated revision.
          policy_path = request.rest_path.first(2) + ["policies", request.rest_path.last,
                                                      "revisions", current_revision_id]

          full_policy_doc = parse_json(get_data(request, policy_path))
          full_policy_doc = ChefData::DataNormalizer.normalize_policy(full_policy_doc, request.rest_path.last, current_revision_id)
          return json_response(200, full_policy_doc)
        end

        return error(404, "Don't know what to do with path #{request.rest_path}")
      end

      private
      def set_opts
        [ :create_dir ]
      end
    end
  end
end
