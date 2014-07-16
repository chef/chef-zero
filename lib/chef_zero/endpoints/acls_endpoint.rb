require 'json'
require 'chef_zero/endpoints/acl_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/THING/NAME/_acls
    # Where THING is:
    # - clients, data, containers, cookbooks, environments
    #   groups, roles, nodes, users
    # or
    # /organizations/ORG/organization/_acl
    class AclsEndpoint < AclBase
      def get(request)
        # Generate 404 if it doesn't exist
        object_path = request.rest_path[0..-2] # Strip off _acl
        require_existence(request, object_path)

        acls = get_acls(request, object_path) # Strip off _acl
        already_json_response(200, populate_defaults(request, JSON.pretty_generate(acls)))
      end

      def get_acls(request, path)
        acl_path = path[0..1] + [ 'acls' ] + path[2..-1]
        acls = get_data(request, acl_path, :nil) || '{}'
        acls = JSON.parse(acls, :create_additions => false)
        container_acls = get_container_acls(request, path)
        acls = DataNormalizer.normalize_acls(acls, path, container_acls)
        acls
      end

      def get_container_acls(request, path)
        if %w(clients containers cookbooks environments groups nodes roles sandboxes).include?(path[2])
          if path[2..3] != ['containers', 'containers']
            return get_acls(request, path[0..1] + [ 'containers', path[2] ])
          end
        end
        return {}
      end
    end
  end
end
