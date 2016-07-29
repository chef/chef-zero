require "chef_zero/data_store/interface_v2"

module ChefZero
  module DataStore
    class V1ToV2Adapter < ChefZero::DataStore::InterfaceV2
      def initialize(real_store, single_org, options = {})
        @real_store = real_store
        @single_org = single_org
        @options = options
        clear
      end

      attr_reader :real_store
      attr_reader :single_org

      def clear
        real_store.clear if real_store.respond_to?(:clear)
      end

      def create_dir(path, name, *options)
        raise DataNotFoundError.new(path) if skip_organizations?(path)
        raise "Cannot create #{name} at #{path} with V1ToV2Adapter: only handles a single org named #{single_org}." if skip_organizations?(path, name)
        raise DataAlreadyExistsError.new(path + [ name ]) if path.size < 2
        fix_exceptions do
          real_store.create_dir(path[2..-1], name, *options)
        end
      end

      def create(path, name, data, *options)
        raise DataNotFoundError.new(path) if skip_organizations?(path)
        raise "Cannot create #{name} at #{path} with V1ToV2Adapter: only handles a single org named #{single_org}." if skip_organizations?(path, name)
        raise DataAlreadyExistsError.new(path + [ name ]) if path.size < 2
        fix_exceptions do
          real_store.create(path[2..-1], name, data, *options)
        end
      end

      def get(path, request = nil)
        raise DataNotFoundError.new(path) if skip_organizations?(path)
        fix_exceptions do
          # Make it so build_uri will include /organizations/ORG inside the V1 data store
          if request && request.rest_base_prefix.size == 0
            old_base_uri = request.base_uri
            request.base_uri = File.join(request.base_uri, "organizations", single_org)
          end
          begin
            real_store.get(path[2..-1], request)
          ensure
            request.base_uri = old_base_uri if request && request.rest_base_prefix.size == 0
          end
        end
      end

      def set(path, data, *options)
        raise DataNotFoundError.new(path) if skip_organizations?(path)
        fix_exceptions do
          real_store.set(path[2..-1], data, *options)
        end
      end

      def delete(path, *options)
        raise DataNotFoundError.new(path) if skip_organizations?(path) && !options.include?(:recursive)
        fix_exceptions do
          real_store.delete(path[2..-1])
        end
      end

      def delete_dir(path, *options)
        raise DataNotFoundError.new(path) if skip_organizations?(path) && !options.include?(:recursive)
        fix_exceptions do
          real_store.delete_dir(path[2..-1], *options)
        end
      end

      def list(path)
        raise DataNotFoundError.new(path) if skip_organizations?(path)
        if path == []
          [ "organizations" ]
        elsif path == [ "organizations" ]
          [ single_org ]
        else
          fix_exceptions do
            real_store.list(path[2..-1])
          end
        end
      end

      def exists?(path)
        return false if skip_organizations?(path)
        fix_exceptions do
          real_store.exists?(path[2..-1])
        end
      end

      def exists_dir?(path)
        return false if skip_organizations?(path)
        if path == []
          true
        elsif path == [ "organizations" ] || path == [ "users" ]
          true
        else
          return false if skip_organizations?(path)
          fix_exceptions do
            real_store.exists_dir?(path[2..-1])
          end
        end
      end

      private

      def fix_exceptions
        begin
          yield
        rescue DataAlreadyExistsError => e
          err = DataAlreadyExistsError.new([ "organizations", single_org ] + e.path, e)
          err.set_backtrace(e.backtrace)
          raise err
        rescue DataNotFoundError => e
          err = DataNotFoundError.new([ "organizations", single_org ] + e.path, e)
          err.set_backtrace(e.backtrace)
          raise e
        end
      end

      def skip_organizations?(path, name = nil)
        if path == []
          false
        elsif path[0] == "organizations"
          if path.size == 1
            false
          elsif path.size >= 2 && path[1] != single_org
            true
          else
            false
          end
        else
          true
        end
      end
    end
  end
end
