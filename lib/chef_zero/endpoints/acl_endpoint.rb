require 'json'
require 'chef_zero/endpoints/acl_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/<thing>/NAME/_acls/PERM
    # Where thing is:
    # clients, data, containers, cookbooks, environments
    # groups, roles, nodes, users
    # or
    # /organizations/ORG/organization/_acl/PERM
    #
    # Where PERM is create,read,update,delete,grant
    class AclEndpoint < AclBase
      def get(request)
        # Generate 404 if it doesn't exist
        object_path = request.rest_path[0..-3] # strip off _acl/PERM
        perm = request.rest_path[-1]
        require_existence(request, object_path)

        if !%w(read create update delete grant).include?(perm)
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
        end

        acls = get_acls(request, object_path)
        already_json_response(200, populate_defaults(request, JSON.pretty_generate({ perm => acls[perm] })))
      end
    end
  end
end
