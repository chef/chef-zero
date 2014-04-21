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
        raise "create_dir not implemented by class #{self.class}"
      end

      def get(path, request=nil)
        raise "create_dir not implemented by class #{self.class}"
      end

      def set(path, data, *options)
        raise "create_dir not implemented by class #{self.class}"
      end

      def delete(path)
        raise "create_dir not implemented by class #{self.class}"
      end

      def delete_dir(path, *options)
        raise "create_dir not implemented by class #{self.class}"
      end

      def list(path)
        raise "create_dir not implemented by class #{self.class}"
      end

      def exists?(path)
        raise "create_dir not implemented by class #{self.class}"
      end

      def exists_dir?(path)
        raise "create_dir not implemented by class #{self.class}"
      end
    end
  end
end
