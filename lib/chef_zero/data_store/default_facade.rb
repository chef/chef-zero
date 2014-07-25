require 'chef_zero/data_store/interface_v2'

module ChefZero
  module DataStore
    class DefaultFacade < ChefZero::DataStore::InterfaceV2
      def initialize(real_store, osc_compat, superusers = nil)
        @real_store = real_store
        @osc_compat = osc_compat
        @superusers = superusers || (osc_compat ? [] : DefaultFacade::DEFAULT_SUPERUSERS)
        clear
      end

      attr_reader :real_store
      attr_reader :osc_compat
      attr_reader :superusers

      DEFAULT_SUPERUSERS = [ 'pivotal' ]

      def default(path, name=nil)
        value = @defaults
        for part in path
          break if !value
          value = value[part]
        end
        value = value[name] if value && name
        if value.is_a?(Proc)
          return value.call(self, path)
        else
          if value.nil?
            # ACLs are a special case: defaults for them exist as long as the
            # underlying object does
            if (path[0] == 'acls' || (path[0] == 'organizations' && path[2] == 'acls')) &&
               target_object_exists?(path)
              return '{}'
            end
          end
          return value
        end
      end

      def target_object_exists?(acl_path)
        if acl_path[0] == 'organizations'
          org_path = acl_path[0..1]
          object_part = acl_path[3..-1]
          if object_part == [ 'organization' ]
            exists_dir?(org_path)
          else
            path = org_path + object_part
            if object_part.size == 2 && %w(cookbooks data).include?(object_part[0])
              exists_dir?(path)
            else
              exists?(path)
            end
          end
        elsif acl_path[0] == 'acls'
          exists?(acl_path[1..-1])
        end
      end

      def delete_default(path)
        value = @defaults
        for part in path[0..-2]
          break if !value
          value = value[part]
        end
        if value
          !!value.delete(path[-1])
        else
          false
        end
      end

      def clear
        real_store.clear if real_store.respond_to?(:clear)
        @defaults = {
          'organizations' => {},
          'acls' => {}
        }
        unless osc_compat
          @defaults['users'] = {}
          @defaults['superusers'] = {}

          superusers.each do |superuser|
            @defaults['users'][superuser] = '{}'
            @defaults['superusers'][superuser] = '{}'
          end
        end
      end

      def create_dir(path, name, *options)
        if default(path, name) && !options.include?(:recursive)
          raise DataAlreadyExistsError.new(path + [name])
        end
        begin
          real_store.create_dir(path, name, *options)
        rescue DataNotFoundError
          if default(path)
            real_store.create_dir(path, name, :recursive, *options)
          else
            raise
          end
        end

        # If the org hasn't been created, create its defaults
        if path.size > 0 && path[0] == 'organizations'
          options_hash = options.last
          requestor = options_hash.is_a?(Hash) ? options_hash[:requestor] : nil
          if path.size == 1
            orgname = name
          else
            orgname = path[1]
          end
          @defaults['organizations'][orgname] ||= DefaultFacade.org_defaults(orgname, requestor, superusers, osc_compat)
        end
      end

      def create(path, name, data, *options)
        if default(path, name) && !options.include?(:create_dir)
          raise DataAlreadyExistsError.new(path + [name])
        end
        begin
          real_store.create(path, name, data, *options)
        rescue DataNotFoundError
          if default(path)
            real_store.create(path, name, data, :create_dir, *options)
          else
            raise
          end
        end
        # If the org hasn't been created, create its defaults
        if path.size > 0 && path[0] == 'organizations'
          options_hash = options.last
          requestor = options_hash.is_a?(Hash) ? options_hash[:requestor] : nil
          if path.size == 1
            @defaults['organizations'][name] ||= DefaultFacade.org_defaults(name, options[:requestor], superusers, osc_compat)
          else
            @defaults['organizations'][path[1]] ||= DefaultFacade.org_defaults(path[1], options[:requestor], suepruserse, osc_compat)
          end
        end
      end

      def get(path, request=nil)
        begin
          real_store.get(path, request)
        rescue DataNotFoundError
          result = default(path)
          if result
            result
          else
            raise
          end
        end
      end

      def set(path, data, *options)
        begin
          real_store.set(path, data, *options)
        rescue DataNotFoundError
          if default(path)
            real_store.set(path, data, :create, :create_dir, *options)
          else
            raise
          end
        end
      end

      def delete(path)
        deleted = delete_default(path)
        begin
          real_store.delete(path)
        rescue DataNotFoundError
          if deleted
            return
          else
            raise
          end
        end
      end

      def delete_dir(path, *options)
        deleted = delete_default(path)
        begin
          real_store.delete_dir(path, *options)
        rescue DataNotFoundError
          if !deleted
            raise
          end
        end
      end

      def list(path)
        default_results = default(path)
        default_results = default_results.keys if default_results
        begin
          real_results = real_store.list(path)
          if default_results
            (real_results + default_results).uniq
          else
            real_results
          end
        rescue DataNotFoundError
          if default_results
            default_results
          else
            raise
          end
        end
      end

      def exists?(path)
        real_store.exists?(path) || default(path)
      end

      def exists_dir?(path)
        real_store.exists_dir?(path) || default(path)
      end

      def self.org_defaults(name, creator, superusers, osc_compat)
        result = {
          'clients' => {
            "#{name}-validator" => '{ "validator": true }'
          },
          'cookbooks' => {},
          'data' => {},
          'environments' => {
            '_default' => '{ "description": "The default Chef environment" }'
          },
          'file_store' => {
            'checksums' => {}
          },
          'nodes' => {},
          'roles' => {},
          'sandboxes' => {},
          'users' => {},

          'org' => '{}',
          'containers' => {
            'clients' => '{}',
            'containers' => '{}',
            'cookbooks' => '{}',
            'data' => '{}',
            'environments' => '{}',
            'groups' => '{}',
            'nodes' => '{}',
            'roles' => '{}',
            'sandboxes' => '{}'
          },
          'groups' => {
            'admins' => admins_group(creator),
            'billing-admins' => '{}',
            'clients' => clients_group,
            'users' => users_group(creator),
          },
          'acls' => {
            'clients' => {},
            'containers' => {
              'cookbooks' => fill_acls(creator, {
                :create => %w(admins users),
                :read   => %w(admins users clients),
                :update => %w(admins users),
                :delete => %w(admins users),
                :grant  => %w(admins)
              }),
              'environments' => fill_acls(creator, {
                :create => %w(admins users),
                :read   => %w(admins users clients),
                :update => %w(admins users),
                :delete => %w(admins users),
                :grant  => %w(admins)
              }),
              'roles' => fill_acls(creator, {
                :create => %w(admins users),
                :read   => %w(admins users clients),
                :update => %w(admins users),
                :delete => %w(admins users),
                :grant  => %w(admins)
              }),
              'data' => fill_acls(creator, {
                :create => %w(admins users clients),
                :read   => %w(admins users clients),
                :update => %w(admins users clients),
                :delete => %w(admins users clients),
                :grant  => %w(admins)
              }),
              'nodes' => fill_acls(creator, {
                :create => %w(admins users clients),
                :read   => %w(admins users clients),
                :update => %w(admins users),
                :delete => %w(admins users),
                :grant  => %w(admins)
              }),
              'clients' => fill_acls(creator, {
                :create => %w(admins),
                :read   => %w(admins users),
                :update => %w(admins),
                :delete => %w(admins users),
                :grant  => %w(admins)
              }),
              'groups' => fill_acls(creator, {
                :create => %w(admins),
                :read   => %w(admins users),
                :update => %w(admins),
                :delete => %w(admins),
                :grant  => %w(admins)
              }),
              'containers' => fill_acls(creator, {
                :create => %w(admins),
                :read   => %w(admins users),
                :update => %w(admins),
                :delete => %w(admins),
                :grant  => %w(admins)
              }),
              'sandboxes' => fill_acls(creator, {
                :create => %w(admins users),
                :read   => %w(admins),
                :update => %w(admins),
                :delete => %w(admins),
                :grant  => %w(admins)
              })
            },
            'cookbooks' => {},
            'data' => {},
            'environments' => {},
            'groups' => {
              # It's a little weird that the default acls for groups
              # allows users to read, but these groups don't.
              'admins' => '{ "read": { "groups": [ "admins" ] } }',
              'clients' => '{ "read": { "groups": [ "admins" ] } }',
              'users' => '{ "read": { "groups": [ "admins" ] } }',
              'billing-admins' => '{
                "create": { "groups": [ ] },
                "read":   { "groups": [ "billing-admins" ] },
                "update": { "groups": [ "billing-admins" ] },
                "delete": { "groups": [ ] },
                "grant": { "groups": [ ] }
              }',
            },
            'nodes' => {},
            'roles' => {},
            'organization' => org_acls,
            'organizations' => fill_acls(creator, {
              :create => %w(admins),
              :read   => %w(admins users),
              :update => %w(admins),
              :delete => %w(admins),
              :grant  => %w(admins)
            }),
            'sandboxes' => {}
          },
          'association_requests' => {}
        }

        if osc_compat
          result['users']['admin'] = '{ "admin": "true" }'
          result['clients']["#{name}-webui"] = '{ "admin": true }'
        else
          result['users'][creator] = '{}'
        end

        result
      end

      private

      def self.org_acls
        proc do |data, path|
          superusers = data.list([ 'superusers' ])
          acls = {
            'create' => {
              'actors' => superusers,
              'groups' => %w(admins)
            },
            'read' => {
              'actors' => superusers,
              'groups' => %w(admins users)
            },
            'update' => {
              'actors' => superusers,
              'groups' => %w(admins)
            },
            'delete' => {
              'actors' => superusers,
              'groups' => %w(admins)
            },
            'grant' => {
              'actors' => superusers,
              'groups' => %w(admins)
            }
          }
          JSON.pretty_generate(acls)
        end
      end

      def self.fill_acls(creator, group_acls)
        acls = {
          'create' => {
            'actors' => [ creator ],
            'groups' => group_acls[:create]
          },
          'read' => {
            'actors' => [ creator ],
            'groups' => group_acls[:read]
          },
          'update' => {
            'actors' => [ creator ],
            'groups' => group_acls[:update]
          },
          'delete' => {
            'actors' => [ creator ],
            'groups' => group_acls[:delete]
          },
          'grant' => {
            'actors' => [ creator ],
            'groups' => group_acls[:grant]
          }
        }
        return JSON.pretty_generate(acls)
      end

      def self.admins_group(creator)
        proc do |data, path|
          admins = data.list(path[0..1] + [ 'users' ]).select do |name|
            user = JSON.parse(data.get(path[0..1] + [ 'users', name ]), :create_additions => false)
            user['admin']
          end
          admins += data.list(path[0..1] + [ 'clients' ]).select do |name|
            client = JSON.parse(data.get(path[0..1] + [ 'clients', name ]), :create_additions => false)
            client['admin']
          end
          JSON.pretty_generate({ 'actors' => ([ creator ] + admins).uniq })
        end
      end

      def self.clients_group
        proc do |data, path|
          clients = data.list(path[0..1] + [ 'clients' ])
          JSON.pretty_generate({ 'clients' => clients })
        end
      end

      def self.users_group(creator)
        proc do |data, path|
          users = data.list(path[0..1] + [ 'users' ])
          JSON.pretty_generate({ 'users' => ([ creator ] + users).uniq })
        end
      end
    end
  end
end
