require 'json'
require 'chef_zero/endpoints/acl_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/THING/NAME/_acl
    # Where THING is:
    # - clients, data, containers, cookbooks, environments
    #   groups, roles, nodes, users
    # or
    # /organizations/ORG/organization/_acl
    # /users/NAME/_acl
    class AclsEndpoint < AclBase
      def get(request)
        path = request.rest_path[0..-2] # Strip off _acl
        acls = DataNormalizer.normalize_acls(get_acls(request, path))
        json_response(200, acls)
      end
    end
  end
end
