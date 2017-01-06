require "digest/md5"
require "hashie"

module ChefZero
  module ChefData
    module CookbookData
      def self.to_hash(cookbook, name, version = nil)
        frozen = false
        if cookbook.has_key?(:frozen)
          frozen = cookbook[:frozen]
          cookbook = cookbook.dup
          cookbook.delete(:frozen)
        end

        result = files_from(cookbook)
        recipe_names = result[:all_files].select do |file|
          file[:name].start_with?("recipes/")
        end.map do |recipe|
          recipe_name = recipe[:name][0..-2]
          recipe_name == "default" ? name : "#{name}::#{recipe_name}"
        end
        result[:metadata] = metadata_from(cookbook, name, version, recipe_names)
        result[:name] = "#{name}-#{result[:metadata][:version]}"
        result[:json_class] = "Chef::CookbookVersion"
        result[:cookbook_name] = name
        result[:version] = result[:metadata][:version]
        result[:chef_type] = "cookbook_version"
        result[:frozen?] = true if frozen
        result
      end

      def self.metadata_from(directory, name, version, recipe_names)
        metadata = PretendCookbookMetadata.new(PretendCookbook.new(name, recipe_names))
        # If both .rb and .json exist, read .json
        if has_child(directory, "metadata.json")
          metadata.from_json(read_file(directory, "metadata.json"))
        elsif has_child(directory, "metadata.rb")
          begin
            file = filename(directory, "metadata.rb") || "(#{name}/metadata.rb)"
            metadata.instance_eval(read_file(directory, "metadata.rb"), file)
          rescue
            ChefZero::Log.error("Error loading cookbook #{name}: #{$!}\n  #{$!.backtrace.join("\n  ")}")
          end
        end
        result = {}
        metadata.to_hash.each_pair do |key, value|
          result[key.to_sym] = value
        end
        result[:version] = version if version
        result
      end

      private

      # Just enough cookbook to make a Metadata object
      class PretendCookbook
        def initialize(name, fully_qualified_recipe_names)
          @name = name
          @fully_qualified_recipe_names = fully_qualified_recipe_names
        end
        attr_reader :name, :fully_qualified_recipe_names
      end

      # Handles loading configuration values from a Chef config file
      #
      # @author Justin Campbell <justin.campbell@riotgames.com>
      class PretendCookbookMetadata < Hash
        # @param [String] path
        def initialize(cookbook)
          self.name(cookbook.name)
          self.recipes(cookbook.fully_qualified_recipe_names)
          %w{attributes grouping dependencies supports recommendations suggestions conflicting providing replacing recipes}.each do |hash_arg|
            self[hash_arg.to_sym] = Hashie::Mash.new
          end
        end

        def from_json(json)
          self.merge!(FFI_Yajl::Parser.parse(json))
        end

        private

        def depends(cookbook, *version_constraints)
          cookbook_arg(:dependencies, cookbook, version_constraints)
        end

        def supports(cookbook, *version_constraints)
          cookbook_arg(:supports, cookbook, version_constraints)
        end

        def provides(cookbook, *version_constraints)
          cookbook_arg(:providing, cookbook, version_constraints)
        end

        def gem(*opts)
          self[:gems] ||= []
          self[:gems] << opts
        end

        def recipe(recipe, description)
          self[:recipes][recipe] = description
        end

        def attribute(name, options)
          self[:attributes][name] = options
        end

        def cookbook_arg(key, cookbook, version_constraints)
          self[key][cookbook] = version_constraints.first || ">= 0.0.0"
        end

        def method_missing(key, *values)
          if values.nil?
            self[key.to_sym]
          else
            if values.length > 1
              store key.to_sym, values
            else
              store key.to_sym, values.first
            end
          end
        end
      end

      def self.files_from(directory)
        # TODO some support .rb only
        result = load_files(directory)

        set_specificity(result, :templates)
        set_specificity(result, :files)

        result = {
          all_files: result,
        }
        result
      end

      def self.has_child(directory, name)
        if directory.is_a?(Hash)
          directory.has_key?(name)
        else
          directory.child(name).exists?
        end
      end

      def self.read_file(directory, name)
        if directory.is_a?(Hash)
          directory[name]
        else
          directory.child(name).read
        end
      end

      def self.filename(directory, name)
        if directory.respond_to?(:file_path)
          File.join(directory.file_path, name)
        else
          nil
        end
      end

      def self.get_directory(directory, name)
        if directory.is_a?(Hash)
          directory[name].is_a?(Hash) ? directory[name] : nil
        else
          result = directory.child(name)
          result.dir? ? result : nil
        end
      end

      def self.list(directory)
        if directory.is_a?(Hash)
          directory.keys
        else
          directory.children.map { |c| c.name }
        end
      end

      def self.load_child_files(parent, key, recursive, part)
        result = load_files(get_directory(parent, key), recursive, part)
        result.each do |file|
          file[:path] = "#{key}/#{file[:path]}"
        end
        result
      end

      def self.load_files(directory, recursive = true, part = nil)
        result = []
        if directory
          list(directory).each do |child_name|
            dir = get_directory(directory, child_name)
            if dir
              child_part = child_name if part.nil?
              if recursive
                result += load_child_files(directory, child_name, recursive, child_part)
              end
            else
              result += load_file(read_file(directory, child_name), child_name, part)
            end
          end
        end
        result
      end

      def self.load_file(value, name, part = nil)
        specific_name = part ? "#{part}/#{name}" : name
        [{
          :name => specific_name,
          :path => name,
          :checksum => Digest::MD5.hexdigest(value),
          :specificity => "default",
        }]
      end

      def self.set_specificity(files, type)
        files.each do |file|
          next unless file[:name].split("/")[0] == type.to_s

          parts = file[:path].split("/")
          file[:specificity] = if parts.size == 2
                                 "default"
                               else
                                 parts[1]
                               end
        end
      end
    end
  end

  CookbookData = ChefData::CookbookData
end
