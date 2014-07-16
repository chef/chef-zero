require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # Extended by AclEndpoint and AclsEndpoint
    class AclBase < RestBase
      def require_existence(request, path)
        if path[2] == 'organization' && path.length == 3
          if !exists_data_dir?(request, path[0..1])
            raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
          end
        else
          if !exists_data?(request, path)
            raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
          end
        end
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
