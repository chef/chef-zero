require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # /organizations/NAME/policies
    class OrganizationPoliciesEndpoint < RestBase
      def hashify_list(list)
        list.reduce({}) { |acc, obj| acc.merge( obj => {} ) }
      end

      def get(request)

        # vanilla /policies.
        if request.rest_path.last == "policies"
          response_data = {}
          policy_names = list_data_or_else(request, nil, [])
          policy_names.each do |policy_name|
            policy_path = request.rest_path + [policy_name]
            policy_uri = build_uri(request.base_uri, policy_path)
            revisions = list_data_or_else(request, policy_path + ["revisions"], {})

            response_data[policy_name] = {
              uri: policy_uri,
              revisions: hashify_list(revisions)
            }
          end

          return json_response(200, response_data)
        end

        # /policies/:policy_name
        if request.rest_path[-2] == "policies"
          if !exists_data_dir?(request)
            return error(404, "Item not found" )
          else
            revisions = list_data(request, request.rest_path + ["revisions"])
            data = { revisions: hashify_list(revisions) }
            return json_response(200, data)
          end
        end

        # /policies/:policy_name/revisions/:revision_id
        if request.rest_path[-2] == "revisions"
          if !exists_data?(request, nil)
            return error(404, "Revision ID #{request.rest_path.last} not found" )
          else
            data = parse_json(get_data(request))
            data = ChefData::DataNormalizer.normalize_policy(data, request.rest_path[3], request.rest_path[5])
            return json_response(200, data)
          end
        end
      end

      def post(request)
        if request.rest_path.last == "revisions"
          # POST /policies/:policy_name/revisions
          # we want to create /policies/{policy_name}/revisions/{revision_id}
          policyfile_data = parse_json(request.body)
          uri_policy_name = request.rest_path[-2]

          if exists_data?(request, request.rest_path + [policyfile_data["revision_id"]])
            return error(409, "Revision ID #{policyfile_data["revision_id"]} already exists.")
          end

          if policyfile_data["name"] != uri_policy_name
            return error(400, "URI policy name #{uri_policy_name} does not match JSON policy name #{policyfile_data["name"]}")
          end

          revision_path = request.rest_path + [policyfile_data["revision_id"]]
          set_data(request, revision_path, request.body, *set_opts)
          return already_json_response(201, request.body)
        end
      end

      def delete(request)
        # /policies/:policy_name/revisions/:revision_id
        if request.rest_path[-2] == "policies"
          revisions = list_data(request, request.rest_path + ["revisions"])
          data = { revisions: hashify_list(revisions) }

          delete_data_dir(request, nil, :recursive)
          return json_response(200, data)
        end

        if request.rest_path[-2] == "revisions"
          if exists_data?(request)
            policyfile_data = parse_json(get_data(request))
            policyfile_data = ChefData::DataNormalizer.normalize_policy(policyfile_data)
            delete_data(request)
            return json_response(200, policyfile_data)
          else
            return error(404, "Revision ID #{request.rest_path.last} not found")
          end
        end
      end

      private
      def set_opts
        [ :create_dir ]
      end
    end
  end
end
