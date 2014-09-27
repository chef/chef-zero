require 'chef_zero/data_store/interface_v2'
require 'chef_zero/chef_data/default_creator'

module ChefZero
  module DataStore
    #
    # The DefaultFacade exists to layer defaults on top of an existing data
    # store.  When you create an org, you just create the directory itself:
    # the rest of the org (such as environments/_default) will not actually
    # exist anywhere, but when you get(/organizations/org/environments/_default),
    # the DefaultFacade will create one for you on the fly.
    #
    # acls in particular are instantiated on the fly using this method.
    #
    class DefaultFacade < ChefZero::DataStore::InterfaceV2
      def initialize(real_store, single_org, osc_compat, superusers = nil)
        @real_store = real_store
        @default_creator = ChefData::DefaultCreator.new(self, single_org, osc_compat, superusers)
        clear
      end

      attr_reader :real_store
      attr_reader :default_creator

      def clear
        real_store.clear if real_store.respond_to?(:clear)
        default_creator.clear
      end

      def create_dir(path, name, *options)
        if default_creator.exists?(path + [ name ]) && !options.include?(:recursive)
          raise DataAlreadyExistsError.new(path + [name])
        end

        begin
          real_store.create_dir(path, name, *options)
        rescue DataNotFoundError
          if default_creator.exists?(path)
            real_store.create_dir(path, name, :recursive, *options)
          else
            raise
          end
        end

        options_hash = options.last.is_a?(Hash) ? options.last : {}
        default_creator.created(path + [ name ], options_hash[:requestor], options.include?(:recursive))
      end

      def create(path, name, data, *options)
        if default_creator.exists?(path + [ name ]) && !options.include?(:create_dir)
          raise DataAlreadyExistsError.new(path + [name])
        end

        begin
          real_store.create(path, name, data, *options)
        rescue DataNotFoundError
          if default_creator.exists?(path)
            real_store.create(path, name, data, :create_dir, *options)
          else
            raise
          end
        end

        options_hash = options.last.is_a?(Hash) ? options.last : {}
        default_creator.created(path + [ name ], options_hash[:requestor], options.include?(:recursive))
      end

      def get(path, request=nil)
        begin
          real_store.get(path, request)
        rescue DataNotFoundError
          result = default_creator.get(path)
          if result
            FFI_Yajl::Encoder.encode(result, :pretty => true)
          else
            raise
          end
        end
      end

      def set(path, data, *options)
        begin
          real_store.set(path, data, *options)
        rescue DataNotFoundError
          if options.include?(:create_dir) ||
             options.include?(:create) && default_creator.exists?(path[0..-2]) ||
             default_creator.exists?(path)
            real_store.set(path, data, :create, :create_dir, *options)
          else
            raise
          end
        end

        if options.include?(:create)
          options_hash = options.last.is_a?(Hash) ? options.last : {}
          default_creator.created(path, options_hash[:requestor], options.include?(:create_dir))
        end
      end

      def delete(path, *options)
        deleted = default_creator.deleted(path)
        begin
          real_store.delete(path)
        rescue DataNotFoundError
          if !deleted
            raise
          end
        end
      end

      def delete_dir(path, *options)
        deleted = default_creator.deleted(path)
        begin
          real_store.delete_dir(path, *options)
        rescue DataNotFoundError
          if !deleted
            raise
          end
        end
      end

      def list(path)
        default_results = default_creator.list(path)
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
        real_store.exists?(path) || default_creator.exists?(path)
      end

      def exists_dir?(path)
        real_store.exists_dir?(path) || default_creator.exists?(path)
      end
    end
  end
end
