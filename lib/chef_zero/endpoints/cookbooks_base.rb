require 'ffi_yajl'
require 'chef_zero/rest_base'
require 'chef_zero/chef_data/data_normalizer'

module ChefZero
  module Endpoints
    # Common code for endpoints that return cookbook lists
    class CookbooksBase < RestBase
      def format_cookbooks_list(request, cookbooks_list, constraints = {}, num_versions = nil)
        results = {}
        filter_cookbooks(cookbooks_list, constraints, num_versions) do |name, versions|
          versions_list = versions.map do |version|
            {
              'url' => build_uri(request.base_uri, request.rest_path[0..1] + ['cookbooks', name, version]),
              'version' => version
            }
          end
          results[name] = {
            'url' => build_uri(request.base_uri, request.rest_path[0..1] + ['cookbooks', name]),
            'versions' => versions_list
          }
        end
        results
      end

      def all_cookbooks_list(request)
        result = {}
        # Race conditions exist here (if someone deletes while listing).  I don't care.
        data_store.list(request.rest_path[0..1] + ['cookbooks']).each do |name|
          result[name] = data_store.list(request.rest_path[0..1] + ['cookbooks', name])
        end
        result
      end

      def filter_cookbooks(cookbooks_list, constraints = {}, num_versions = nil)
        cookbooks_list.keys.sort.each do |name|
          constraint = Gem::Requirement.new(constraints[name])
          versions = []
          cookbooks_list[name].sort_by { |version| Gem::Version.new(version.dup) }.reverse.each do |version|
            break if num_versions && versions.size >= num_versions
            if constraint.satisfied_by?(Gem::Version.new(version.dup))
              versions << version
            end
          end
          yield [name, versions]
        end
      end

      def recipe_names(cookbook_name, cookbook)
        result = []
        if cookbook['recipes']
          cookbook['recipes'].each do |recipe|
            if recipe['path'] == "recipes/#{recipe['name']}" && recipe['name'][-3..-1] == '.rb'
              if recipe['name'] == 'default.rb'
                result << cookbook_name
              end
              result << "#{cookbook_name}::#{recipe['name'][0..-4]}"
            end
          end
        end
        result
      end
    end
  end
end
