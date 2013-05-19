require 'digest/md5'

module ChefZero
  module CookbookData
    def self.to_hash(cookbook, name, version=nil)
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
      end

      def from_json(filepath)
        self.merge!(JSON.parse(File.read(filepath)))
      end

      private

      def method_missing(key, value = nil)
        if value.nil?
          self[key.to_sym]
        else
          store key.to_sym, value
        end
      end
    end

    def self.metadata_from(directory, name, version, recipe_names)
      metadata = PretendCookbookMetadata.new(PretendCookbook.new(name, recipe_names))
      # If both .rb and .json exist, read .rb
      # TODO if recipes has 3 recipes in it, and the Ruby/JSON has only one, should
      # the resulting recipe list have 1, or 3-4 recipes in it?
      if directory['metadata.rb']
        metadata.instance_eval(directory['metadata.rb'])
      elsif directory['metadata.json']
        metadata.from_json(directory['metadata.json'])
      end
      result = {}
      metadata.to_hash.each_pair do |key,value|
        result[key.to_sym] = value
      end
      result[:version] = version
      result
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

    def self.load_child_files(parent, key, recursive)
      result = load_files(parent[key], recursive)
      result.each do |file|
        file[:path] = "#{key}/#{file[:path]}"
      end
      result
    end

    def self.load_files(directory, recursive)
      result = []
      if directory
        directory.each_pair do |child_key, child|
          if child.is_a? Hash
            if recursive
              result += load_child_files(directory, child_key, recursive)
           end
          else
            result += load_file(child, child_key)
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
