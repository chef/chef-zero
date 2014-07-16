require 'json'
require 'chef_zero/rest_base'

module ChefZero
  module Endpoints
    # Extended by AclEndpoint and AclsEndpoint
    class AclBase < RestBase
      def acl_path(path)
        if path[0] == 'organizations' && path.size > 1
          acl_path = path[0..1] + [ 'acls' ] + path[2..-1]
        else
          acl_path = [ 'acls' ] + path
        end
      end

      def get_acls(request, path)
        acls = get_data(request, acl_path(path))
        acls = JSON.parse(acls, :create_additions => false)
        container_acls = get_container_acls(request, path)
        if container_acls
          DataNormalizer.merge_container_acls(acls, container_acls)
        else
          acls
        end
      end

      def get_container_acls(request, path)
        if path[0] == 'organizations'
          if %w(clients containers cookbooks environments groups nodes roles sandboxes).include?(path[2])
            if path[2..3] != ['containers', 'containers']
              return get_acls(request, path[0..1] + [ 'containers', path[2] ])
            end
          end
        end
        return nil
      end
    end
  end
end
