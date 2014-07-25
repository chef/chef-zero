require 'json'
require 'chef_zero/rest_base'
require 'chef_zero/data_normalizer'
require 'chef_zero/data_store/default_facade'

module ChefZero
  module Endpoints
    # Extended by AclEndpoint and AclsEndpoint
    class AclBase < RestBase
      def acl_path(path)
        if path[0] == 'organizations' && path.size > 2
          acl_path = path[0..1] + [ 'acls' ] + path[2..-1]
        elsif path[0] == 'organizations' && path.size == 2
          acl_path = path + %w(acls organizations)
        else
          acl_path = [ 'acls' ] + path
        end
      end

      def get_acls(request, path)
        acls = get_data(request, acl_path(path))
        acls = JSON.parse(acls, :create_additions => false)
        container_acls = get_container_acls(request, path)
        if container_acls
          acls = DataNormalizer.merge_container_acls(acls, container_acls)
        end

        # We merge owners into every acl, because we're awesome like that.
        owners = owners_of(path)

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

      def owners_of(path)
        # The objects that were created with the org itself, and containers for
        # some reason, have the peculiar property of missing pivotal from their acls.
        if is_created_with_org?(path, false) || path[0] == 'organizations' && path[2] == 'containers'
          list_metadata(path[0..1], 'owners')
        else
          result = list_metadata(path, 'owners', :recurse_up)
          if path.size == 4 && path[0] == 'organizations' && path[2] == 'clients'
            result |= [ path[3] ]
          end
          result
        end
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

      # Used by owners_of to find all owners of a thing by looking up
      # the trail of directories
      def list_metadata(path, metadata_type, *options)
        begin
          result = data_store.list([ 'metadata', metadata_type, path.join('/') ])
        rescue DataStore::DataNotFoundError
          result = []
        end
        if options.include?(:recurse_up) && path.size >= 1
          result = list_metadata(path[0..-2], metadata_type, *options) | result
        end
        return result
      end
    end
  end
end
