require 'ffi_yajl'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /organizations/NAME
    class OrganizationEndpoint < RestBase
      def get(request)
        org = get_data(request, request.rest_path + [ 'org' ])
        already_json_response(200, populate_defaults(request, org))
      end

      def put(request)
        org = FFI_Yajl::Parser.parse(get_data(request, request.rest_path + [ 'org' ]), :create_additions => false)
        new_org = FFI_Yajl::Parser.parse(request.body, :create_additions => false)
        new_org.each do |key, value|
          org[key] = value
        end
        save_org = FFI_Yajl::Encoder.encode(org, :pretty => true)
        if new_org['name'] != request.rest_path[-1]
          # This is a rename
          return error(400, "Cannot rename org #{request.rest_path[-1]} to #{new_org['name']}: rename not supported for orgs")
        end
        set_data(request, request.rest_path + [ 'org' ], save_org)
        json_response(200, {
          "uri" => "#{build_uri(request.base_uri, request.rest_path)}",
          "name" => org['name'],
          "org_type" => org['org_type'],
          "full_name" => org['full_name']
        })
      end

      def delete(request)
        org = get_data(request, request.rest_path + [ 'org' ])
        delete_data_dir(request, request.rest_path, :recursive)

        delete_validator_client!(request, request.rest_path[-1])

        already_json_response(200, populate_defaults(request, org))
      end

      def populate_defaults(request, response_json)
        org = FFI_Yajl::Parser.parse(response_json, :create_additions => false)
        org = ChefData::DataNormalizer.normalize_organization(org, request.rest_path[1])
        FFI_Yajl::Encoder.encode(org, :pretty => true)
      end

      private

      def validator_name(org_name)
        "#{org_name}-validator"
      end

      def delete_validator_client!(request, org_name)
        client_path = [ *request.rest_path, 'clients', validator_name(org_name) ]
        client_data = get_data(request, client_path, :nil)

        if client_data
          delete_data(request, client_path, :data_store_exceptions)
        end

        delete_validator_client_keys!(request, org_name)
      rescue DataStore::DataNotFoundError
      end

      def delete_validator_client_keys!(request, org_name)
        keys_path = [ "organizations", org_name,
                      "client_keys", validator_name(org_name) ]
        delete_data_dir(request, keys_path, :recursive, :data_store_exceptions)
      rescue DataStore::DataNotFoundError
      end
    end
  end
end
