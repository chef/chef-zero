require 'chef_zero/data_store/interface_v2'

module ChefZero
  module DataStore
    class V1ToV2Adapter < ChefZero::DataStore::InterfaceV2
      def initialize(real_store, single_org, options = {})
        @real_store = real_store
        @single_org = single_org
        org_defaults = options[:org_defaults] || {
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
        @defaults = { 'organizations' => { single_org => org_defaults }}
      end

      attr_reader :real_store
      attr_reader :single_org

      def clear
        real_store.clear
      end

      def create_dir(path, name, *options)
        return nil if skip_organizations?(path, name)
        if using_default?(path, name)
          raise DataAlreadyExistsError.new(path + [name])
        end
        fix_exceptions do
          real_store.create_dir(path[2..-1], name, *options)
        end
      end

      def create(path, name, data, *options)
        return nil if skip_organizations?(path, name)
        if using_default?(path, name)
          raise DataAlreadyExistsError.new(path + [name])
        end
        remove_default(path, name)

        fix_exceptions do
          real_store.create(path[2..-1], name, data, *options)
        end
      end

      def get(path, request=nil)
        return nil if skip_organizations?(path)
        if using_default?(path)
          get_default(path)
        else
          fix_exceptions do
            real_store.get(path[2..-1], request)
          end
        end
      end

      def set(path, data, *options)
        return nil if skip_organizations?(path)
        remove_default(path)
        fix_exceptions do
          real_store.set(path[2..-1], data, *options)
        end
      end

      def delete(path)
        return nil if skip_organizations?(path)
        remove_default(path)
        fix_exceptions do
          real_store.delete(path[2..-1])
        end
      end

      def delete_dir(path, *options)
        return nil if skip_organizations?(path)
        fix_exceptions do
          real_store.delete_dir(path[2..-1], *options)
        end
      end

      def list(path)
        return nil if skip_organizations?(path)
        fix_exceptions do
          result = real_store.list(path[2..-1])
          if using_default?(path)
            result ||= []
            get_default(path).keys.each do |value|
              result << value if !result.include?(value)
            end
          end
          result
        end
      end

      def exists?(path)
        return nil if skip_organizations?(path)
        if using_default?(path)
          true
        else
          fix_exceptions do
            real_store.exists?(path[2..-1])
          end
        end
      end

      def exists_dir?(path)
        return nil if skip_organizations?(path)
        if using_default?(path)
          true
        else
          fix_exceptions do
            real_store.exists_dir?(path[2..-1])
          end
        end
      end

      private

      def using_default?(path, name = nil)
        path = path + [name] if name
        result = @defaults
        path.each do |part|
          return false if !result.has_key?(part)
          result = result[part]
        end
        !result.nil?
      end

      def get_default(path, name = nil)
        path = path + [name] if name
        result = @defaults
        path.each do |part|
          return nil if !result.has_key?(part)
          result = result[part]
        end
        result
      end

      def remove_default(path, name = nil)
        dir = name ? path[0..-2] : path
        default = @defaults
        dir.each do |part|
          return if !default.has_key?(part)
          default = default[part]
        end

        name = name || path.last
        if name
          default.delete(name)
        end
      end

      def fix_exceptions
        begin
          yield
        rescue DataAlreadyExistsError => e
          raise DataAlreadyExistsError.new([ 'organizations', single_org ] + e.path, e)
        rescue DataNotFoundError => e
          raise DataNotFoundError.new([ 'organizations', single_org ] + e.path, e)
        end
      end

      def skip_organizations?(path, name = nil)
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
