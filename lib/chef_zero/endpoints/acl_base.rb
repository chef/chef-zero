require 'json'
require 'chef_zero/rest_base'
require 'chef_zero/data_normalizer'
require 'chef_zero/data_store/default_facade'

module ChefZero
  module Endpoints
    # Extended by AclEndpoint and AclsEndpoint
    class AclBase < RestBase
      def get_acls(request, path)
        acls = get_data(request, acl_path(path))
        acls = JSON.parse(acls, :create_additions => false)

        container_acls = get_container_acls(request, path)
        if container_acls
          acls = merge_container_acls(acls, container_acls)
        end

        # We merge owners into every acl, because we're awesome like that.
        # The objects that were created with the org itself, and containers for
        # some reason, have the peculiar property of missing pivotal from their acls.
        if is_created_with_org?(path, false) || path[0] == 'organizations' && path[2] == 'containers'
          owners = []
        else
          owners = superusers
          # Clients need to be in their own acl list
          if path.size == 4 && path[0] == 'organizations' && path[2] == 'clients'
            owners |= [ path[3] ]
          end
        end

        %w(create read update delete grant).each do |perm|
          acls[perm] ||= {}
          acls[perm]['actors'] ||= []
          # The owners of the org and of the server (the superusers) have rights too
          acls[perm]['actors'] = owners | acls[perm]['actors']
          acls[perm]['groups'] ||= []
        end
        acls
      end

      private

      def merge_container_acls(acls, container_acls)
        container_acls.each_pair do |perm, who|
          acls[perm] ||= {}
          acls[perm]['actors'] ||= container_acls[perm]['actors']
          acls[perm]['groups'] ||= container_acls[perm]['groups']
        end
        acls
      end

      def get_container_acls(request, path)
        if path[0] == 'organizations'
          if %w(clients cookbooks data environments groups nodes roles sandboxes).include?(path[2])
            return get_acls(request, path[0..1] + [ 'containers', path[2] ])
          elsif path[2] == 'containers'
            # When we create containers, we don't merge them with the container container.
            # Go figure.
            if path[3] != 'containers' && is_created_with_org?(path)
              return get_acls(request, path[0..1] + [ 'containers', path[2] ])
            end
          end
        end
        return nil
      end

      def superusers
        data_store.list([ 'superusers' ])
      end

      def is_created_with_org?(path, osc_compat = false)
        return false if path.size == 0 || path[0] != 'organizations'
        value = DataStore::DefaultFacade.org_defaults(path[1], 'pivotal', [], osc_compat)
        for part in path[2..-1]
          break if !value
          value = value[part]
        end
        return !!value
      end
    end
  end
end
