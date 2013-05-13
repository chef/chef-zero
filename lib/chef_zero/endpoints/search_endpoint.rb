require 'json'
require 'chef_zero/endpoints/rest_object_endpoint'
require 'chef_zero/data_normalizer'
require 'chef_zero/rest_error_response'
require 'chef_zero/solr/solr_parser'
require 'chef_zero/solr/solr_doc'

module ChefZero
  module Endpoints
    # /search/INDEX
    class SearchEndpoint < RestBase
      def get(request)
        results = search(request)
        results['rows'] = results['rows'].map { |name,uri,value,search_value| value }
        json_response(200, results)
      end

      def post(request)
        full_results = search(request)
        keys = JSON.parse(request.body, :create_additions => false)
        partial_results = full_results['rows'].map do |name, uri, doc, search_value|
          data = {}
          keys.each_pair do |key, path|
            if path.size > 0
              value = search_value
              path.each do |path_part|
                value = value[path_part] if !value.nil?
              end
              data[key] = value
            else
              data[key] = nil
            end
          end
          {
            'url' => uri,
            'data' => data
          }
        end
        json_response(200, {
          'rows' => partial_results,
          'start' => full_results['start'],
          'total' => full_results['total']
        })
      end

      private

      def search_container(request, index)
        case index
        when 'client'
          [ data['clients'], Proc.new { |client, name| DataNormalizer.normalize_client(client, name) }, build_uri(request.base_uri, [ 'clients' ]) ]
        when 'node'
          [ data['nodes'], Proc.new { |node, name| DataNormalizer.normalize_node(node, name) }, build_uri(request.base_uri, [ 'nodes' ]) ]
        when 'environment'
          [ data['environments'], Proc.new { |environment, name| DataNormalizer.normalize_environment(environment, name) }, build_uri(request.base_uri, [ 'environments' ]) ]
        when 'role'
          [ data['roles'], Proc.new { |role, name| DataNormalizer.normalize_role(role, name) }, build_uri(request.base_uri, [ 'roles' ]) ]
        else
          [ data['data'][index], Proc.new { |data_bag_item, id| DataNormalizer.normalize_data_bag_item(data_bag_item, index, id, 'DELETE') }, build_uri(request.base_uri, [ 'data', index ]) ]
        end
      end

      def expand_for_indexing(value, index, id)
        if index == 'node'
          result = {}
          result.deep_merge!(value['default'] || {})
          result.deep_merge!(value['normal'] || {})
          result.deep_merge!(value['override'] || {})
          result.deep_merge!(value['automatic'] || {})
          result['recipe'] = []
          result['role'] = []
          if value['run_list']
            value['run_list'].each do |run_list_entry|
              if run_list_entry =~ /^(recipe|role)\[(.*)\]/
                result[$1] << $2
              end
            end
          end
          value.each_pair do |key, value|
            result[key] = value unless %w(default normal override automatic).include?(key)
          end
          result

        elsif !%w(client environment role).include?(index)
          DataNormalizer.normalize_data_bag_item(value, index, id, 'GET')
        else
          value
        end
      end

      def search(request)
        # Extract parameters
        index = request.rest_path[1]
        query_string = request.query_params['q'] || '*:*'
        solr_query = ChefZero::Solr::SolrParser.new(query_string).parse
        sort_string = request.query_params['sort']
        start = request.query_params['start']
        start = start.to_i if start
        rows = request.query_params['rows']
        rows = rows.to_i if rows

        # Get the search container
        container, expander, base_uri = search_container(request, index)
        if container.nil?
          raise RestErrorResponse.new(404, "Object not found: #{build_uri(request.base_uri, request.rest_path)}")
        end

        # Search!
        result = []
        container.each_pair do |name,value|
          expanded = expander.call(JSON.parse(value, :create_additions => false), name)
          result << [ name, build_uri(base_uri, [name]), expanded, expand_for_indexing(expanded, index, name) ]
        end
        result = result.select do |name, uri, value, search_value|
          solr_query.matches_doc?(ChefZero::Solr::SolrDoc.new(search_value, name))
        end
        total = result.size

        # Sort
        if sort_string
          sort_key, sort_order = sort_string.split(/\s+/, 2)
          result = result.sort_by { |name,uri,value,search_value| ChefZero::Solr::SolrDoc.new(search_value, name)[sort_key] }
          result = result.reverse if sort_order == "DESC"
        end

        # Paginate
        if start
          result = result[start..start+(rows||-1)]
        end
        {
          'rows' => result,
          'start' => start || 0,
          'total' => total
        }
      end
    end
  end
end
