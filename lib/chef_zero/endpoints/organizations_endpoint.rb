require 'json'
require 'chef_zero/rest_base'
require 'uuidtools'

module ChefZero
  module Endpoints
    # /organizations
    class OrganizationsEndpoint < RestBase
      def get(request)
        result = {}
        data_store.list(request.rest_path).each do |name|
          result[name] = build_uri(request.base_uri, request.rest_path + [name])
        end
        json_response(200, result)
      end

      def post(request)
        contents = request.body
        name = JSON.parse(contents, :create_additions => false)['name']
        if name.nil?
          error(400, "Must specify 'name' in JSON")
        elsif exists_data_dir?(request, request.rest_path + [ name ])
          error(409, "Organization already exists")
        else
          create_data_dir(request, request.rest_path, name)

          org = {
            "guid" => UUIDTools::UUID.random_create,
            "assigned_at" => Time.now.to_s
          }
          org_path = request.rest_path + [ name ]
          set_data(request, org_path + [ 'org' ], JSON.pretty_generate(org))

          if server.generate_real_keys?
            # Create the validator client
            validator_name = "#{name}-validator"
            validator_path = org_path + [ 'clients', validator_name ]
            private_key, public_key = server.gen_key_pair
            validator = JSON.pretty_generate({
              'validator' => true,
              'public_key' => public_key
            })
            set_data(request, validator_path, validator)
          end

          json_response(201, {
            "uri" => "#{build_uri(request.base_uri, org_path)}",
            "clientname" => validator_name,
            "private_key" => private_key
          })
        end
      end
    end
  end
end
