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
        path = path[0..1] if path.size == 3 && path[0] == 'organizations' && path[2] == 'organizations'
        acls = DataNormalizer.normalize_acls(get_acls(request, path))
        json_response(200, acls)
      end

      # Remove these to get them doing 405 again like they ought to
      def put(request)
        raise RestErrorResponse.new(404, "Method not allowed: POST #{build_uri(request.base_uri, request.rest_path)}")
      end

      def post(request)
        raise RestErrorResponse.new(404, "Method not allowed: POST #{build_uri(request.base_uri, request.rest_path)}")
      end

      def delete(request)
        raise RestErrorResponse.new(404, "Method not allowed: DELETE #{build_uri(request.base_uri, request.rest_path)}")
      end
    end
  end
end
