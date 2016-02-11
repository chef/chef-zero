require 'ffi_yajl'
require 'chef_zero/rest_base'
require 'chef_zero/chef_data/data_normalizer'
require 'uuidtools'

module ChefZero
  module Endpoints
    # /organizations
    class OrganizationsEndpoint < RestBase
      DEFAULT_PUBLIC_KEY_NAME = "default"

      def get(request)
        result = {}
        data_store.list(request.rest_path).each do |name|
          result[name] = build_uri(request.base_uri, request.rest_path + [name])
        end
        json_response(200, result)
      end

      def post(request)
        contents = FFI_Yajl::Parser.parse(request.body, :create_additions => false)
        name = contents['name']
        full_name = contents['full_name']
        if name.nil?
          error(400, "Must specify 'name' in JSON")
        elsif full_name.nil?
          error(400, "Must specify 'full_name' in JSON")
        elsif exists_data_dir?(request, request.rest_path + [ name ])
          error(409, "Organization already exists")
        else
          create_data_dir(request, request.rest_path, name, :requestor => request.requestor)

          org = {
            "guid" => UUIDTools::UUID.random_create.to_s.gsub('-', ''),
            "assigned_at" => Time.now.to_s
          }.merge(contents)

          org_path = request.rest_path + [ name ]
          set_data(request, org_path + [ 'org' ], FFI_Yajl::Encoder.encode(org, :pretty => true))

          if server.generate_real_keys?
            private_key = create_validator_client!(request, org_path)
          end

          json_response(201, {
            "uri" => build_uri(request.base_uri, org_path),
            "name" => name,
            "org_type" => org["org_type"],
            "full_name" => full_name,
            "clientname" => validator_name(name),
            "private_key" => private_key
          })
        end
      end

      private

      def validator_name(org_name)
        "#{org_name}-validator"
      end

      def create_validator_client!(request, org_path)
        org_name = org_path.last
        name = validator_name(org_name)

        validator_path = [ *org_path, 'clients', name ]

        private_key, public_key = server.gen_key_pair

        validator = FFI_Yajl::Encoder.encode({
          'validator' => true,
        }, :pretty => true)

        set_data(request, validator_path, validator)

        store_validator_public_key!(request, org_name, name, public_key)

        private_key
      end

      # Store the validator client's public key in client_keys
      def store_validator_public_key!(request, org_name, client_name, public_key)
        path = [ "organizations", org_name,
                 "client_keys", client_name, "keys" ]

        data = FFI_Yajl::Encoder.encode(
          "name" => DEFAULT_PUBLIC_KEY_NAME,
          "public_key" => public_key,
          "expiration_date" => "infinity"
        )

        create_data(request, path, DEFAULT_PUBLIC_KEY_NAME, data, :create_dir)
      end
    end
  end
end
