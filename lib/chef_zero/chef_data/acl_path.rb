module ChefZero
  module ChefData
    # Manages translations between REST and ACL data paths
    # and parent paths.
    #
    # Suggestions
    # - make /organizations/ORG/_acl and deprecate organization/_acl and organizations/_acl
    # - add endpoints for /containers/(users|organizations|containers)(/_acl)
    # - add PUT for */_acl
    # - add endpoints for /organizations/ORG/data/containers and /organizations/ORG/cookbooks/containers
    # - sane, fully documented ACL model
    # - sane inheritance / override model: if actors or groups are explicitly
    #   specified on X, they are not inherited from X's parent
    # - stop adding pivotal to acls (he already has access to what he needs)
    module AclPath
      ORG_DATA_TYPES = %w(clients cookbooks containers data environments groups nodes roles sandboxes)
      TOP_DATA_TYPES = %w(containers organizations users)

      # ACL data paths for a partition are:
      # /          -> /acls/root
      # /TYPE      -> /acls/containers/TYPE
      # /TYPE/NAME -> /acls/TYPE/NAME
      #
      # The root partition "/" has its own acls, so it looks like this:
      #
      # / -> /acls/root
      # /users -> /acls/containers/users
      # /organizations -> /acls/containers/organizations
      # /users/schlansky -> /acls/users/schlansky
      #
      # Each organization is its own partition, so it looks like this:
      #
      # /organizations/blah           -> /organizations/blah/acls/root
      # /organizations/blah/roles     -> /organizations/blah/acls/containers/roles
      # /organizations/blah/roles/web -> /organizations/blah/acls/roles/web
      # /organizations/ORG is its own partition.  ACLs for anything under it follow

      # This method takes a Chef REST path and returns the chef-zero path
      # used to look up the ACL.  If an object does not have an ACL directly,
      # it will return nil.  Paths like /organizations/ORG/data/bag/item will
      # return nil, because it is the parent path (data/bag) that has an ACL.
      def self.get_acl_data_path(path)
        # Things under organizations have their own acls hierarchy
        if path[0] == 'organizations' && path.size >= 2
          under_org = partition_acl_data_path(path[2..-1], ORG_DATA_TYPES)
          if under_org
            path[0..1] + under_org
          end
        else
          partition_acl_data_path(path, TOP_DATA_TYPES)
        end
      end

      #
      # Reverse transform from acl_data_path to path.
      # /acls/root -> /
      # /acls/** -> /**
      # /organizations/ORG/acls/root -> /organizations/ORG
      # /organizations/ORG/acls/** -> /organizations/ORG/**
      #
      # This means that /acls/containers/nodes maps to
      # /containers/nodes, not /nodes.
      #
      def self.get_object_path(acl_data_path)
        if acl_data_path[0] == 'acls'
          if acl_data_path[1] == 'root'
            []
          else
            acl_data_path[1..-1]
          end
        elsif acl_data_path[0] == 'organizations' && acl_data_path[2] == 'acls'
          if acl_data_path[3] == 'root'
            acl_data_path[0..1]
          else
            acl_data_path[0..1] + acl_data_path[3..-1]
          end
        end
      end

      # Method *assumes* acl_data_path is valid.
      # /organizations/BLAH's parent is /organizations
      #
      # An example traversal up the whole tree:
      # /organizations/foo/acls/nodes/mario ->
      # /organizations/foo/acls/containers/nodes ->
      # /organizations/foo/acls/containers/containers ->
      # /organizations/foo/acls/root ->
      # /acls/containers/organizations ->
      # /acls/containers/containers ->
      # /acls/root ->
      # nil
      def self.parent_acl_data_path(acl_data_path)
        if acl_data_path[0] == 'organizations'
          under_org = partition_parent_acl_data_path(acl_data_path[2..-1])
          if under_org
            acl_data_path[0..1] + under_org
          else
            # ACL data path is /organizations/X/acls/root; therefore parent is "/organizations"
            [ 'acls', 'containers', 'organizations' ]
          end
        else
          partition_parent_acl_data_path(acl_data_path)
        end
      end

      private

      # /acls/root -> nil
      # /acls/containers/containers -> /acls/root
      # /acls/TYPE/X -> /acls/containers/TYPE
      #
      # Method *assumes* acl_data_path is valid.
      # Returns nil if the path is /acls/root
      def self.partition_parent_acl_data_path(acl_data_path)
        if acl_data_path.size == 3
          if acl_data_path == %w(acls containers containers)
            [ 'acls', 'root' ]
          else
            [ 'acls', 'containers', acl_data_path[1]]
          end
        else
          nil
        end
      end

      def self.partition_acl_data_path(path, data_types)
        if path.size == 0
          [ 'acls', 'root']
        elsif data_types.include?(path[0])
          if path.size == 0
            [ 'acls', 'containers', path[0] ]
          elsif path.size == 2
            [ 'acls', path[0], path[1] ]
          end
        end
      end
    end
  end
end
