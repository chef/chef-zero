require 'digest/md5'
require 'chef/cookbook/metadata' # for ruby metadata.rb dsl

module ChefZero
  module CookbookData
    def self.to_json(cookbook, name, version=nil)
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

    def self.metadata_from(directory, name, version, recipe_names)
      metadata = Chef::Cookbook::Metadata.new(PretendCookbook.new(name, recipe_names))
      # If both .rb and .json exist, read .rb
      # TODO if recipes has 3 recipes in it, and the Ruby/JSON has only one, should
      # the resulting recipe list have 1, or 3-4 recipes in it?
      if cookbook['metadata.rb']
        metadata.instance_eval(cookbook['metadata.rb'])
      elsif cookbook['metadata.json']
        metadata.from_json(cookbook['metadata.json'])
      end
      metadata.to_json
    end

    def self.files_from(cookbook)
      # TODO some support .rb only
      result = {
        :attributes => load_child_files(cookbook, 'attributes', false),
        :definitions => load_child_files(cookbook, 'definitions', false),
        :recipes => load_child_files(cookbook, 'recipes', false),
        :libraries => load_child_files(cookbook, 'libraries', false),
        :templates => load_child_files(cookbook, 'templates', true, true),
        :files => load_child_files(cookbook, 'files', true, true),
        :resources => load_child_files(cookbook, 'resources', true),
        :providers => load_child_files(cookbook, 'providers', true),
        :root_files => load_files(cookbook, false)
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
      directory.each_pair do |child_key, child|
        if child.is_a? Hash
          if recursive
            result += load_child_files(directory, child_key, recursive, false)
         end
        else
          result += load_file(child, child_key)
        end
      end
      result.each do |file|
        file[:path] = "key/#{file[:path]}"
      end
      result
    end

    def self.load_file(value, name)
      result = {
        :name => name,
        :path => name,
        :checksum => Digest::MD5.hexdigest(value),
        :specificity => 'default'
      }
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
