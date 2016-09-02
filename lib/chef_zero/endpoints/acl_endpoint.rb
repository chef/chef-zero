require "ffi_yajl"
require "chef_zero/rest_base"
require "chef_zero/chef_data/acl_path"

module ChefZero
  module Endpoints
    # /organizations/ORG/<thing>/NAME/_acl/PERM
    # Where thing is:
    # clients, data, containers, cookbooks, environments
    # groups, roles, nodes, users
    # or
    # /organizations/ORG/organization/_acl/PERM
    # or
    # /users/NAME/_acl/PERM
    #
    # Where PERM is create,read,update,delete,grant
    class AclEndpoint < RestBase
      def validate_request(request)
        path = request.rest_path[0..-3] # Strip off _acl/PERM
        path = path[0..1] if path.size == 3 && path[0] == "organizations" && %w{organization organizations}.include?(path[2])
        acl_path = ChefData::AclPath.get_acl_data_path(path)
        perm = request.rest_path[-1]
        if !acl_path || !%w{read create update delete grant}.include?(perm)
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
        end
        [acl_path, perm]
      end

      def put(request)
        path, perm = validate_request(request)
        acls = FFI_Yajl::Parser.parse(get_data(request, path))
        acls[perm] = FFI_Yajl::Parser.parse(request.body)[perm]
        set_data(request, path, FFI_Yajl::Encoder.encode(acls, :pretty => true))
        json_response(200, { "uri" => "#{build_uri(request.base_uri, request.rest_path)}" })
      end
    end
  end
end
