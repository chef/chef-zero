require "chef_zero/chef_data/acl_path"

module ChefZero
  module ChefData
    #
    # The DefaultCreator creates default values when you ask for them.
    # - It relies on created and deleted being called when things get
    #   created and deleted, so that it knows the owners of said objects
    #   and knows to eliminate default values on delete.
    # - get, list and exists? get data.
    #
    class DefaultCreator
      def initialize(data, single_org, osc_compat, superusers = nil)
        @data = data
        @single_org = single_org
        @osc_compat = osc_compat
        @superusers = superusers || DEFAULT_SUPERUSERS
        clear
      end

      attr_reader :data
      attr_reader :single_org
      attr_reader :osc_compat
      attr_reader :creators
      attr_reader :deleted

      PERMISSIONS = %w{create read update delete grant}
      DEFAULT_SUPERUSERS = %w{pivotal}

      def clear
        @creators = { [] => @superusers }
        @deleted = {}
      end

      def deleted(path)
        # acl deletes mean nothing, they are entirely subservient to their
        # parent object
        if path[0] == "acls" || (path[0] == "organizations" && path[2] == "acls")
          return false
        end

        result = exists?(path)
        @deleted[path] = true
        result
      end

      def deleted?(path)
        1.upto(path.size) do |index|
          return true if @deleted[path[0..-index]]
        end
        false
      end

      def created(path, creator, create_parents)
        # If a parent has been deleted, we will need to clear that.
        deleted_index = nil
        0.upto(path.size - 1) do |index|
          deleted_index = index if @deleted[path[0..index]]
        end

        # Walk up the tree, setting the creator on anything that doesn't exist
        # (anything that is either deleted or was never created)
        while (deleted_index && path.size > deleted_index) || !@creators[path]
          @creators[path] = creator ? [ creator ] : []
          @deleted.delete(path)
          # Only do this once if create_parents is false
          break if !create_parents || path.size == 0

          path = path[0..-2]
        end
      end

      def superusers
        @creators[[]]
      end

      def get(path)
        return nil if deleted?(path)

        result = case path[0]
                 when "acls"
                   # /acls/*
                   object_path = AclPath.get_object_path(path)
                   if data_exists?(object_path)
                     default_acl(path)
                   end

                 when "containers"
                   if path.size == 2 && exists?(path)
                     {}
                   end

                 when "users"
                   if path.size == 2 && data.exists?(path)
                     # User is empty user
                     {}
                   end

                 when "organizations"
                   if path.size >= 2
                     # /organizations/*/**
                     if data.exists_dir?(path[0..1])
                       get_org_default(path)
                     end
                   end
                 end

        result
      end

      def list(path)
        return nil if deleted?(path)

        if path.size == 0
          return %w{containers users organizations acls}
        end

        case path[0]
        when "acls"
          if path.size == 1
            [ "root" ] + (data.list(path + [ "containers" ]) - [ "organizations" ])
          else
            data.list(AclPath.get_object_path(path))
          end

        when "containers"
          %w{containers users organizations}

        when "users"
          superusers

        when "organizations"
          if path.size == 1
            single_org ? [ single_org ] : []
          elsif path.size >= 2 && data.exists_dir?(path[0..1])
            list_org_default(path)
          end
        end
      end

      def exists?(path)
        return true if path.size == 0
        parent_list = list(path[0..-2])
        parent_list && parent_list.include?(path[-1])
      end

      protected

      DEFAULT_ORG_SPINE = {
        "clients" => {},
        "cookbook_artifacts" => {},
        "cookbooks" => {},
        "data" => {},
        "environments" => %w{_default},
        "file_store" => {
          "checksums" => {},
        },
        "nodes" => {},
        "policies" => {},
        "policy_groups" => {},
        "roles" => {},
        "sandboxes" => {},
        "users" => {},

        "org" => {},
        "containers" => %w{clients containers cookbook_artifacts cookbooks data environments groups nodes policies policy_groups roles sandboxes},
        "groups" => %w{admins billing-admins clients users},
        "association_requests" => {},
      }

      def list_org_default(path)
        if path.size >= 3 && path[2] == "acls"
          if path.size == 3
            # /organizations/ORG/acls
            return [ "root" ] + data.list(path[0..1] + [ "containers" ])
          elsif path.size == 4
            # /organizations/ORG/acls/TYPE
            return data.list(path[0..1] + [ path[3] ])
          else
            return nil
          end
        end

        value = DEFAULT_ORG_SPINE
        2.upto(path.size - 1) do |index|
          value = nil if @deleted[path[0..index]]
          break if !value
          value = value[path[index]]
        end

        result = if value.is_a?(Hash)
                   value.keys
                 elsif value
                   value
                 end

        if path.size == 3
          if path[2] == "clients"
            result << "#{path[1]}-validator"
            if osc_compat
              result << "#{path[1]}-webui"
            end
          elsif path[2] == "users"
            if osc_compat
              result << "admin"
            end
          end
        end

        result
      end

      def get_org_default(path)
        if path[2] == "acls"
          get_org_acl_default(path)

        elsif path.size >= 4
          if path[2] == "containers" && path.size == 4
            if exists?(path)
              return {}
            else
              return nil
            end
          end

          # /organizations/(*)/clients/\1-validator
          # /organizations/*/environments/_default
          # /organizations/*/groups/{admins,billing-admins,clients,users}
          case path[2..-1].join("/")
          when "clients/#{path[1]}-validator"
            { "validator" => "true" }

          when "clients/#{path[1]}-webui", "users/admin"
            if osc_compat
              { "admin" => "true" }
            end

          when "environments/_default"
            { "description" => "The default Chef environment" }

          when "groups/admins"
            admins = data.list(path[0..1] + [ "users" ]).select do |name|
              user = FFI_Yajl::Parser.parse(data.get(path[0..1] + [ "users", name ]))
              user["admin"]
            end
            admins += data.list(path[0..1] + [ "clients" ]).select do |name|
              client = FFI_Yajl::Parser.parse(data.get(path[0..1] + [ "clients", name ]))
              client["admin"]
            end
            admins += @creators[path[0..1]] if @creators[path[0..1]]
            { "actors" => admins.uniq }

          when "groups/billing-admins"
            {}

          when "groups/clients"
            { "clients" => data.list(path[0..1] + [ "clients" ]) }

          when "groups/users"
            users = data.list(path[0..1] + [ "users" ])
            users |= @creators[path[0..1]] if @creators[path[0..1]]
            { "users" => users }

          when "org"
            {}

          end
        end
      end

      def get_org_acl_default(path)
        object_path = AclPath.get_object_path(path)
        # The actual things containers correspond to don't have to exist, as
        # long as the container does
        return nil if !data_exists?(object_path)
        basic_acl =
          case path[3..-1].join("/")
          when "root", "containers/containers", "containers/groups"
            {
              "create" => { "groups" => %w{admins} },
              "read"   => { "groups" => %w{admins users} },
              "update" => { "groups" => %w{admins} },
              "delete" => { "groups" => %w{admins} },
              "grant"  => { "groups" => %w{admins} },
            }
          when "containers/environments", "containers/roles",
            "containers/policy_groups", "containers/policies",
            "containers/cookbooks", "containers/cookbook_artifacts",
            "containers/data"
            {
              "create" => { "groups" => %w{admins users} },
              "read"   => { "groups" => %w{admins users clients} },
              "update" => { "groups" => %w{admins users} },
              "delete" => { "groups" => %w{admins users} },
              "grant"  => { "groups" => %w{admins} },
            }
          when "containers/nodes"
            {
              "create" => { "groups" => %w{admins users clients} },
              "read"   => { "groups" => %w{admins users clients} },
              "update" => { "groups" => %w{admins users} },
              "delete" => { "groups" => %w{admins users} },
              "grant"  => { "groups" => %w{admins} },
            }
          when "containers/clients"
            {
              "create" => { "groups" => %w{admins} },
              "read"   => { "groups" => %w{admins users} },
              "update" => { "groups" => %w{admins} },
              "delete" => { "groups" => %w{admins users} },
              "grant"  => { "groups" => %w{admins} },
            }
          when "containers/sandboxes"
            {
              "create" => { "groups" => %w{admins users} },
              "read"   => { "groups" => %w{admins} },
              "update" => { "groups" => %w{admins} },
              "delete" => { "groups" => %w{admins} },
              "grant"  => { "groups" => %w{admins} },
            }
          when "groups/admins", "groups/clients", "groups/users"
            {
              "create" => { "groups" => %w{admins} },
              "read"   => { "groups" => %w{admins} },
              "update" => { "groups" => %w{admins} },
              "delete" => { "groups" => %w{admins} },
              "grant"  => { "groups" => %w{admins} },
            }
          when "groups/billing-admins"
            {
              "create" => { "groups" => %w{} },
              "read"   => { "groups" => %w{billing-admins} },
              "update" => { "groups" => %w{billing-admins} },
              "delete" => { "groups" => %w{} },
              "grant"  => { "groups" => %w{} },
            }
          else
            {}
          end

        default_acl(path, basic_acl)
      end

      def get_owners(acl_path)
        unknown_owners = []
        path = AclPath.get_object_path(acl_path)
        if path

          # Non-validator clients own themselves.
          if path.size == 4 && path[0] == "organizations" && path[2] == "clients"
            begin
              client = FFI_Yajl::Parser.parse(data.get(path))
              if !client["validator"]
                unknown_owners |= [ path[3] ]
              end
            rescue
              unknown_owners |= [ path[3] ]
            end

            # Add creators as owners (except any validator clients).
            if @creators[path]
              @creators[path].each do |creator|
                begin
                  client = FFI_Yajl::Parser.parse(data.get(path[0..2] + [ creator ]))
                  next if client["validator"]
                rescue
                end
                unknown_owners |= [ creator ]
              end
            end
          else
            unknown_owners |= @creators[path] if @creators[path]
          end
          owners = filter_owners(path, unknown_owners)

          #ANGRY
          # Non-default containers do not get superusers added to them,
          # because reasons.
          unless path.size == 4 && path[0] == "organizations" && path[2] == "containers" && !exists?(path)
            owners[:users] += superusers
          end
        else
          owners = { clients: [], users: [] }
        end

        owners[:users].uniq!
        owners[:clients].uniq!
        owners
      end

      # Figures out if an  object was created by a user or client.
      # If the object does not exist in the context
      # of an organization, it can only be a user
      #
      # This isn't perfect, because we are never explicitly told
      # if a requestor creating an object is a user or client -
      # but it gets us reasonably close
      def filter_owners(path, unknown_owners)
        owners = { clients: [], users: [] }
        unknown_owners.each do |entity|
          if path[0] == "organizations" && path.length > 2
            begin
              data.get(["organizations", path[1], "clients", entity])
              owners[:clients] |= [ entity ]
            rescue
              owners[:users] |= [ entity ]
            end
          else
            owners[:users] |= [ entity ]
          end
        end
        owners
      end

      def default_acl(acl_path, acl = {})
        owners = get_owners(acl_path)
        container_acl = nil
        PERMISSIONS.each do |perm|
          acl[perm] ||= {}
          acl[perm]["users"] = owners[:users]
          acl[perm]["clients"] = owners[:clients]
          acl[perm]["groups"] ||= begin
            # When we create containers, we don't merge groups (not sure why).
            if acl_path[0] == "organizations" && acl_path[3] == "containers"
              []
            else
              container_acl ||= get_container_acl(acl_path) || {}
              (container_acl[perm] ? container_acl[perm]["groups"] : []) || []
            end
          end
          acl[perm]["actors"] = acl[perm]["clients"] + acl[perm]["users"]
        end
        acl
      end

      def get_container_acl(acl_path)
        parent_path = AclPath.parent_acl_data_path(acl_path)
        if parent_path
          FFI_Yajl::Parser.parse(data.get(parent_path))
        else
          nil
        end
      end

      def data_exists?(path)
        if is_dir?(path)
          data.exists_dir?(path)
        else
          data.exists?(path)
        end
      end

      def is_dir?(path)
        case path.size
        when 0, 1
          return true
        when 2
          return path[0] == "organizations" || (path[0] == "acls" && path[1] != "root")
        when 3
          # If it has a container, it is a directory.
          return path[0] == "organizations" &&
              (path[2] == "acls" || data.exists?(path[0..1] + [ "containers", path[2] ]))
        when 4
          return path[0] == "organizations" && (
            (path[2] == "acls" && path[1] != "root") ||
            %w{cookbooks cookbook_artifacts data policies policy_groups}.include?(path[2]))
        else
          return false
        end
      end
    end
  end
end
