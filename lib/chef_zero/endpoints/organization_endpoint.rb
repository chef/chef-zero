require "ffi_yajl"
require "chef_zero/rest_base"

module ChefZero
  module Endpoints
    # /organizations/NAME
    class OrganizationEndpoint < RestBase
      def get(request)
        org = get_data(request, request.rest_path + [ "org" ])
        already_json_response(200, populate_defaults(request, org))
      end

      def put(request)
        org = FFI_Yajl::Parser.parse(get_data(request, request.rest_path + [ "org" ]))
        new_org = FFI_Yajl::Parser.parse(request.body)
        new_org.each do |key, value|
          org[key] = value
        end
        save_org = FFI_Yajl::Encoder.encode(org, :pretty => true)
        if new_org["name"] != request.rest_path[-1]
          # This is a rename
          return error(400, "Cannot rename org #{request.rest_path[-1]} to #{new_org['name']}: rename not supported for orgs")
        end
        set_data(request, request.rest_path + [ "org" ], save_org)
        json_response(200, {
          "uri" => "#{build_uri(request.base_uri, request.rest_path)}",
          "name" => org["name"],
          "org_type" => org["org_type"],
          "full_name" => org["full_name"],
        })
      end

      def delete(request)
        org = get_data(request, request.rest_path + [ "org" ])
        delete_data_dir(request, request.rest_path, :recursive)
        already_json_response(200, populate_defaults(request, org))
      end

      def populate_defaults(request, response_json)
        org = FFI_Yajl::Parser.parse(response_json)
        org = ChefData::DataNormalizer.normalize_organization(org, request.rest_path[1])
        FFI_Yajl::Encoder.encode(org, :pretty => true)
      end
    end
  end
end
