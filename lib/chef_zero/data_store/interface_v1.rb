module ChefZero
  module DataStore
    class InterfaceV1
      def interface_version
        1
      end

      def clear
        raise "clear not implemented by class #{self.class}"
      end

      # Create a directory.
      # options is a list of symbols, including:
      #   :recursive - create any parents needed
      def create_dir(path, name, *options)
        raise "create_dir not implemented by class #{self.class}"
      end

      # Create a file.
      # options is a list of symbols, including:
      #   :create_dir - create any parents needed
      def create(path, name, data, *options)
        raise "create not implemented by class #{self.class}"
      end

      # Get a file.
      def get(path, request=nil)
        raise "get not implemented by class #{self.class}"
      end

      # Set a file's value.
      # options is a list of symbols, including:
      #    :create - create the file if it does not exist
      #    :create_dir - create the directory if it does not exist
      def set(path, data, *options)
        raise "set not implemented by class #{self.class}"
      end

      # Delete a file.
      def delete(path)
        raise "delete not implemented by class #{self.class}"
      end

      # Delete a directory.
      # options is a list of symbols, including:
      #   :recursive - delete even if empty
      def delete_dir(path, *options)
        raise "delete_dir not implemented by class #{self.class}"
      end

      # List a directory.
      def list(path)
        raise "list not implemented by class #{self.class}"
      end

      # Check a file's existence.
      def exists?(path)
        raise "exists? not implemented by class #{self.class}"
      end

      # Check a directory's existence.
      def exists_dir?(path)
        raise "exists_dir? not implemented by class #{self.class}"
      end
    end
  end
end
