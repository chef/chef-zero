require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # /organizations/ORG/<thing>/NAME/_acls
    # Where thing is:
    # clients/NAME
    # data/NAME
    # containers/NAME
    # cookbooks/NAME
    # environments/NAME
    # groups/NAME
    # roles/NAME
    # nodes/NAME
    # users/NAME
    # or
    # /organizations/ORG/organization/_acl
    class AclsEndpoint < RestBase
      def initialize(server)
        super(server)
      end

      def get(request)
        # Generate 404 if it doesn't exist
        if request.rest_path[2] == 'organization' && request.rest_path.length == 4
          list_data(request, request.rest_path[0..1])
        else
          get_data(request, request.rest_path[0..-2])
        end

        acls = get_acls(request, request.rest_path[0..-2]) # Strip off _acl
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
