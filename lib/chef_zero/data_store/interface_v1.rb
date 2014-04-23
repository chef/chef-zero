module ChefZero
  module DataStore
    class InterfaceV1
      def interface_version
        1
      end

      def clear
        raise "clear not implemented by class #{self.class}"
      end

      def create_dir(path, name, *options)
        raise "create_dir not implemented by class #{self.class}"
      end

      def create(path, name, data, *options)
        raise "create not implemented by class #{self.class}"
      end

      def get(path, request=nil)
        raise "get not implemented by class #{self.class}"
      end

      def set(path, data, *options)
        raise "set not implemented by class #{self.class}"
      end

      def delete(path)
        raise "delete not implemented by class #{self.class}"
      end

      def delete_dir(path, *options)
        raise "delete_dir not implemented by class #{self.class}"
      end

      def list(path)
        raise "list not implemented by class #{self.class}"
      end

      def exists?(path)
        raise "exists? not implemented by class #{self.class}"
      end

      def exists_dir?(path)
        raise "exists_dir? not implemented by class #{self.class}"
      end
    end
  end
end
