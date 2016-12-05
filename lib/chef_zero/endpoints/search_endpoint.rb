require "ffi_yajl"
require "chef_zero/endpoints/rest_object_endpoint"
require "chef_zero/chef_data/data_normalizer"
require "chef_zero/rest_error_response"
require "chef_zero/solr/solr_parser"
require "chef_zero/solr/solr_doc"

module ChefZero
  module Endpoints
    # /search/INDEX
    class SearchEndpoint < RestBase
      def get(request)
        orgname = request.rest_path[1]
        results = search(request, orgname)

        results["rows"] = results["rows"].map { |name, uri, value, search_value| value }

        json_response(200, results)
      rescue ChefZero::Solr::ParseError
        bad_search_request(request)
      end

      def post(request)
        orgname = request.rest_path[1]
        full_results = search(request, orgname)
        keys = FFI_Yajl::Parser.parse(request.body)
        partial_results = full_results["rows"].map do |name, uri, doc, search_value|
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
            "url" => uri,
            "data" => data,
          }
        end
        json_response(200, {
          "rows" => partial_results,
          "start" => full_results["start"],
          "total" => full_results["total"],
        })
      rescue ChefZero::Solr::ParseError
        bad_search_request(request)
      end

      private

      def bad_search_request(request)
        query_string = request.query_params["q"]
        resp = { "error" => ["invalid search query: '#{query_string}'"] }
        json_response(400, resp)
      end

      def search_container(request, index, orgname)
        relative_parts, normalize_proc =
          case index
          when "client"
            [ ["clients"], Proc.new { |client, name| ChefData::DataNormalizer.normalize_client(client, name, orgname) } ]
          when "node"
            [ ["nodes"], Proc.new { |node, name| ChefData::DataNormalizer.normalize_node(node, name) } ]
          when "environment"
            [ ["environments"], Proc.new { |environment, name| ChefData::DataNormalizer.normalize_environment(environment, name) } ]
          when "role"
            [ ["roles"], Proc.new { |role, name| ChefData::DataNormalizer.normalize_role(role, name) } ]
          else
            [ ["data", index], Proc.new { |data_bag_item, id| ChefData::DataNormalizer.normalize_data_bag_item(data_bag_item, index, id, "DELETE") } ]
          end

        [
          request.rest_path[0..1] + relative_parts,
          normalize_proc,
        ]
      end

      def expand_for_indexing(value, index, id)
        if index == "node"
          result = {}
          deep_merge!(value["default"] || {}, result)
          deep_merge!(value["normal"] || {}, result)
          deep_merge!(value["override"] || {}, result)
          deep_merge!(value["automatic"] || {}, result)
          result["recipe"] = []
          result["role"] = []
          if value["run_list"]
            value["run_list"].each do |run_list_entry|
              if run_list_entry =~ /^(recipe|role)\[(.*)\]/
                result[$1] << $2
              end
            end
          end
          value.each_pair do |key, value|
            result[key] = value unless %w{default normal override automatic}.include?(key)
          end
          result

        elsif !%w{client environment role}.include?(index)
          ChefData::DataNormalizer.normalize_data_bag_item(value, index, id, "GET")
        else
          value
        end
      end

      def search(request, orgname = nil)
        # Extract parameters
        index = request.rest_path[3]
        query_string = request.query_params["q"] || "*:*"
        solr_query = ChefZero::Solr::SolrParser.new(query_string).parse
        sort_string = request.query_params["sort"]
        start = request.query_params["start"].to_i
        rows = request.query_params["rows"].to_i

        # Get the search container
        container, expander = search_container(request, index, orgname)

        # Search!
        result = []
        list_data(request, container).each do |name|
          value = get_data(request, container + [name])
          expanded = expander.call(FFI_Yajl::Parser.parse(value), name)
          result << [ name, build_uri(request.base_uri, container + [name]), expanded, expand_for_indexing(expanded, index, name) ]
        end
        result = result.select do |name, uri, value, search_value|
          solr_query.matches_doc?(ChefZero::Solr::SolrDoc.new(search_value, name))
        end
        total = result.size

        # Sort
        if sort_string
          sort_key, sort_order = sort_string.split(/\s+/, 2)
          result = result.sort_by { |name, uri, value, search_value| ChefZero::Solr::SolrDoc.new(search_value, name)[sort_key] }
          result = result.reverse if sort_order == "DESC"
        end

        {
          # Paginate
          #
          # Slice the array based on the value of the "rows" query parameter. If
          # this is a positive integer, we'll get the number of rows asked for.
          # If it's nil, we'll get -1, which gives us all of the elements.
          #
          # Do the same for "start", which will start at 0 if that value is not
          # given.
          "rows" => result[start..(rows - 1)],
          # Also return start and total in the object
          "start" => start,
          "total" => total,
        }
      end

      private

      # Deep Merge core documentation.
      # deep_merge! method permits merging of arbitrary child elements. The two top level
      # elements must be hashes. These hashes can contain unlimited (to stack limit) levels
      # of child elements. These child elements to not have to be of the same types.
      # Where child elements are of the same type, deep_merge will attempt to merge them together.
      # Where child elements are not of the same type, deep_merge will skip or optionally overwrite
      # the destination element with the contents of the source element at that level.
      # So if you have two hashes like this:
      #   source = {:x => [1,2,3], :y => 2}
      #   dest =   {:x => [4,5,'6'], :y => [7,8,9]}
      #   dest.deep_merge!(source)
      #   Results: {:x => [1,2,3,4,5,'6'], :y => 2}
      # By default, "deep_merge!" will overwrite any unmergeables and merge everything else.
      # To avoid this, use "deep_merge" (no bang/exclamation mark)
      def deep_merge!(source, dest)
        # if dest doesn't exist, then simply copy source to it
        if dest.nil?
          dest = source; return dest
        end

        case source
        when nil
          dest
        when Hash
          source.each do |src_key, src_value|
            if dest.kind_of?(Hash)
              if dest[src_key]
                dest[src_key] = deep_merge!(src_value, dest[src_key])
              else # dest[src_key] doesn't exist so we take whatever source has
                dest[src_key] = src_value
              end
            else # dest isn't a hash, so we overwrite it completely
              dest = source
            end
          end
        when Array
          if dest.kind_of?(Array)
            dest = dest | source
          else
            dest = source
          end
        when String
          dest = source
        else # src_hash is not an array or hash, so we'll have to overwrite dest
          dest = source
        end
        dest
      end # deep_merge!
    end
  end
end
