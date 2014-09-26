require 'digest/md5'
require 'hashie/mash'

module ChefZero
  module ChefData
    module CookbookData
      def self.to_hash(cookbook, name, version=nil)
        frozen = false
        if cookbook.has_key?(:frozen)
          frozen = cookbook[:frozen]
          cookbook = cookbook.dup
          cookbook.delete(:frozen)
        end

        result = files_from(cookbook)
        recipe_names = result[:recipes].map do |recipe|
          recipe_name = recipe[:name][0..-2]
          recipe_name == 'default' ? name : "#{name}::#{recipe_name}"
        end
        result[:metadata] = metadata_from(cookbook, name, version, recipe_names)
        result[:name] = "#{name}-#{result[:metadata][:version]}"
        result[:json_class] = 'Chef::CookbookVersion'
        result[:cookbook_name] = name
        result[:version] = result[:metadata][:version]
        result[:chef_type] = 'cookbook_version'
        result[:frozen?] = true if frozen
        result
      end

      def self.metadata_from(directory, name, version, recipe_names)
        metadata = PretendCookbookMetadata.new(PretendCookbook.new(name, recipe_names))
        # If both .rb and .json exist, read .rb
        # TODO if recipes has 3 recipes in it, and the Ruby/JSON has only one, should
        # the resulting recipe list have 1, or 3-4 recipes in it?
        if has_child(directory, 'metadata.rb')
          begin
            file = filename(directory, 'metadata.rb') || "(#{name}/metadata.rb)"
            metadata.instance_eval(read_file(directory, 'metadata.rb'), file)
          rescue
            ChefZero::Log.error("Error loading cookbook #{name}: #{$!}\n  #{$!.backtrace.join("\n  ")}")
          end
        elsif has_child(directory, 'metadata.json')
          metadata.from_json(read_file(directory, 'metadata.json'))
        end
        result = {}
        metadata.to_hash.each_pair do |key,value|
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
          %w(attributes grouping dependencies supports recommendations suggestions conflicting providing replacing recipes).each do |hash_arg|
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

        def recommends(cookbook, *version_constraints)
          cookbook_arg(:recommendations, cookbook, version_constraints)
        end

        def suggests(cookbook, *version_constraints)
          cookbook_arg(:suggestions, cookbook, version_constraints)
        end

        def conflicts(cookbook, *version_constraints)
          cookbook_arg(:conflicting, cookbook, version_constraints)
        end

        def provides(cookbook, *version_constraints)
          cookbook_arg(:providing, cookbook, version_constraints)
        end

        def replaces(cookbook, *version_constraints)
          cookbook_arg(:replacing, cookbook, version_constraints)
        end

        def recipe(recipe, description)
          self[:recipes][recipe] = description
        end

        def attribute(name, options)
          self[:attributes][name] = options
        end

        def grouping(name, options)
          self[:grouping][name] = options
        end

        def cookbook_arg(key, cookbook, version_constraints)
          self[key][cookbook] = version_constraints.first || ">= 0.0.0"
        end

        def method_missing(key, value = nil)
          if value.nil?
            self[key.to_sym]
          else
            store key.to_sym, value
          end
        end
      end

      def self.files_from(directory)
        # TODO some support .rb only
        result = {
          :attributes => load_child_files(directory, 'attributes', false),
          :definitions => load_child_files(directory, 'definitions', false),
          :recipes => load_child_files(directory, 'recipes', false),
          :libraries => load_child_files(directory, 'libraries', false),
          :templates => load_child_files(directory, 'templates', true),
          :files => load_child_files(directory, 'files', true),
          :resources => load_child_files(directory, 'resources', true),
          :providers => load_child_files(directory, 'providers', true),
          :root_files => load_files(directory, false)
        }
        set_specificity(result[:templates])
        set_specificity(result[:files])
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

      def self.load_child_files(parent, key, recursive)
        result = load_files(get_directory(parent, key), recursive)
        result.each do |file|
          file[:path] = "#{key}/#{file[:path]}"
        end
        result
      end

      def self.load_files(directory, recursive)
        result = []
        if directory
          list(directory).each do |child_name|
            dir = get_directory(directory, child_name)
            if dir
              if recursive
                result += load_child_files(directory, child_name, recursive)
              end
            else
              result += load_file(read_file(directory, child_name), child_name)
            end
          end
        end
        result
      end

      def self.load_file(value, name)
        [{
          :name => name,
          :path => name,
          :checksum => Digest::MD5.hexdigest(value),
          :specificity => 'default'
        }]
      end

      def self.set_specificity(files)
        files.each do |file|
          parts = file[:path].split('/')
          raise "Only directories are allowed directly under templates or files: #{file[:path]}" if parts.size == 2
          file[:specificity] = parts[1]
        end
      end
    end
  end

  CookbookData = ChefData::CookbookData
end
