require 'chef_zero/data_store/interface_v2'

module ChefZero
  module DataStore
    class V1ToV2Adapter < ChefZero::DataStore::InterfaceV2
      def initialize(real_store, single_org)
        @real_store = real_store
        @single_org = single_org
        # Handle defaults per V2 specification
        @defaults = {
          'clients' => {
            'chef-validator' => '{ "validator": true }',
            'chef-webui' => '{ "admin": true }'
          },
          'environments' => {
            '_default' => '{ "description": "The default Chef environment" }'
          },
          'users' => {
            'admin' => '{ "admin": "true" }'
          }
        }
      end

      attr_reader :real_store
      attr_reader :single_org

      def clear
        real_store.clear
      end

      def create_dir(path, name, *options)
        return nil if skip_organizations(path, name)
        real_store.create_dir(path[2..-1], name, *options)
      end

      def create(path, name, data, *options)
        return nil if skip_organizations(path, name)
        remove_default(path, name)
        real_store.create(path[2..-1], name, data, *options)
      end

      def get(path, request=nil)
        return nil if skip_organizations(path)
        begin
          real_store.get(path[2..-1], request)
        rescue DataNotFoundError
          if path.size == 2 && @defaults[path[0]] && @defaults[path[0]][path[1]]
            @defaults[path[0]][path[1]]
          else
            raise
          end
        end
      end

      def set(path, data, *options)
        return nil if skip_organizations(path)
        remove_default(path, name)
        real_store.set(path[2..-1], data, *options)
      end

      def delete(path)
        return nil if skip_organizations(path)
        remove_default(path)
        real_store.delete(path[2..-1])
      end

      def delete_dir(path, *options)
        return nil if skip_organizations(path)
        real_store.delete_dir(path[2..-1], *options)
      end

      def list(path)
        return nil if skip_organizations(path)
        real_store.list(path[2..-1])
      end

      def exists?(path)
        return nil if skip_organizations(path)
        if path.size == 2 && @defaults[path[0]] && @defaults[path[0]][path[1]]
          @defaults[path[0]][path[1]]
        else
          real_store.exists?(path[2..-1])
        end
      end

      def exists_dir?(path)
        return nil if skip_organizations(path)
        real_store.exists_dir?(path[2..-1])
      end

      private

      def remove_default(path, name = nil)
        path = path + [name] if name
        if path.size == 2 && @defaults[path[0]] && @defaults[path[0]][path[1]]
          @defaults[path[0]].delete(path[1])
        end
      end

      def skip_organizations(path, name = nil)
        if path == []
          raise "" if name == nil || name != 'organizations'
          true
        elsif path == ['organizations']
          raise "" if name == nil || name != single_org
          true
        else
          raise "Path #{path} must start with /organizations/#{single_org}" if path[0..1] != [ 'organizations', single_org ]
          if !name
            raise "Path #{path} must start with /organizations/#{single_org}/<something>" if path.size <= 2
          end
          false
        end
      end
    end
  end
end
