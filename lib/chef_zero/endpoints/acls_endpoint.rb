require 'ffi_yajl'
require 'chef_zero/rest_base'
require 'chef_zero/chef_data/data_normalizer'
require 'chef_zero/chef_data/acl_path'

module ChefZero
  module Endpoints
    # /organizations/ORG/THING/NAME/_acl
    # Where THING is:
    # - clients, data, containers, cookbooks, environments
    #   groups, roles, nodes, users
    # or
    # /organizations/ORG/organization/_acl
    # /users/NAME/_acl
    class AclsEndpoint < RestBase
      def get(request)
        path = request.rest_path[0..-2] # Strip off _acl
        path = path[0..1] if path.size == 3 && path[0] == 'organizations' && %w(organization organizations).include?(path[2])
        acl_path = ChefData::AclPath.get_acl_data_path(path)
        if !acl_path
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
        end
        acls = FFI_Yajl::Parser.parse(get_data(request, acl_path), :create_additions => false)
        acls = ChefData::DataNormalizer.normalize_acls(acls)
        json_response(200, acls)
      end
    end
  end
end
