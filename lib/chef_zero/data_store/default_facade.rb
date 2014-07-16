require 'chef_zero/data_store/interface_v2'

module ChefZero
  module DataStore
    class DefaultFacade < ChefZero::DataStore::InterfaceV2
      def initialize(real_store)
        @real_store = real_store
        clear
      end

      attr_reader :real_store

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
          return value
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
          'organizations' => {}
        }
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
          if path.size == 1
            @defaults['organizations'][name] ||= org_defaults(name)
          else
            @defaults['organizations'][path[1]] ||= org_default(path[1])
          end
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
          if path.size == 1
            @defaults['organizations'][name] ||= org_defaults(name)
          else
            @defaults['organizations'][path[1]] ||= org_defaults(path[1])
          end
        end
      end

      def get(path, request=nil)
        begin
          real_store.get(path, request=nil)
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
            real_store.create(path[0..-2], path[-1], data, *options)
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

      def org_defaults(name)
        {
          'clients' => {
            "#{name}-validator" => '{ "validator": true }',
            "#{name}-webui" => '{ "admin": true }'
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
          'users' => {
            'admin' => '{ "admin": "true" }'
          },

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
            'admins' => admins_group,
            'billing-admins' => '{}',
            'clients' => clients_group,
            'users' => users_group,
          },
          'acls' => {
            'clients' => {},
            'containers' => {
              'cookbooks' => '{
                "create": { "groups": [ "admins", "users" ] },
                "read":   { "groups": [ "admins", "users", "clients" ] },
                "update": { "groups": [ "admins", "users" ] },
                "delete": { "groups": [ "admins", "users" ] }
              }',
              'environments' => '{
                "create": { "groups": [ "admins", "users" ] },
                "read":   { "groups": [ "admins", "users", "clients" ] },
                "update": { "groups": [ "admins", "users" ] },
                "delete": { "groups": [ "admins", "users" ] }
              }',
              'roles' => '{
                "create": { "groups": [ "admins", "users" ] },
                "read":   { "groups": [ "admins", "users", "clients" ] },
                "update": { "groups": [ "admins", "users" ] },
                "delete": { "groups": [ "admins", "users" ] }
              }',
              'data' => '{
                "create": { "groups": [ "admins", "users", "clients" ] },
                "read":   { "groups": [ "admins", "users", "clients" ] },
                "update": { "groups": [ "admins", "users", "clients" ] },
                "delete": { "groups": [ "admins", "users", "clients" ] },
              }',
              'nodes' => '{
                "create": { "groups": [ "admins", "users", "clients" ] },
                "read":   { "groups": [ "admins", "users", "clients" ] },
                "update": { "groups": [ "admins", "users" ] },
                "delete": { "groups": [ "admins", "users" ] }
              }',
              'clients' => client_container_acls,
              'groups' => '{
                "read":   { "groups": [ "admins", "users" ] }
              }',
              'containers' => '{
                "read":   { "groups": [ "admins", "users" ] }
              }',
              'sandboxes' => '{
                "create":   { "groups": [ "admins", "users" ] }
              }'
            },
            'cookbooks' => {},
            'data' => {},
            'environments' => {},
            'groups' => {
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
            'sandboxes' => {}
          }
        }
      end

      def admins_group
        proc do |data, path|
          admins = data.list(path[0..1] + [ 'users' ]).select do |name|
            user = JSON.parse(data.get(path[0..1] + [ 'users', name ]), :create_additions => false)
            user['admin']
          end
          admins += data.list(path[0..1] + [ 'clients' ]).select do |name|
            client = JSON.parse(data.get(path[0..1] + [ 'clients', name ]), :create_additions => false)
            client['admin']
          end
          JSON.pretty_generate({ 'actors' => admins })
        end
      end

      def clients_group
        proc do |data, path|
          clients = data.list(path[0..1] + [ 'clients' ])
          JSON.pretty_generate({ 'actors' => clients })
        end
      end

      def users_group
        proc do |data, path|
          users = data.list(path[0..1] + [ 'users' ])
          JSON.pretty_generate({ 'users' => users })
        end
      end

      def client_container_acls
        proc do |data, path|
          validators = data.list(path[0..1] + [ 'clients' ]).select do |name|
            client = JSON.parse(data.get(path[0..1] + [ 'clients', name ]), :create_additions => false)
            client['validator']
          end

          JSON.pretty_generate({
            'create' => { "actors" => [ validators] },
            'read' => { 'groups' => [ 'admins', 'users' ] },
            'delete' => { 'groups' => [ 'admins', 'users' ] }
          })
        end
      end
    end
  end
end
