module ChefZero
  module Solr
    # This does what expander does, flattening the json doc into keys and values
    # so that solr can search them.
    class SolrDoc
      def initialize(json, id)
        @json = json
        @id = id
      end

      def [](key)
        matching_values { |match_key| match_key == key }
      end

      def matching_values(&block)
        result = []
        key_values(nil, @json) do |key, value|
          if yield(key)
            result << value.to_s
          end
        end
        # Handle manufactured value(s)
        if yield("X_CHEF_id_CHEF_X")
          result << @id.to_s
        end

        result.uniq
      end

      private

      def key_values(key_so_far, value, &block)
        if value.is_a?(Hash)
          value.each_pair do |child_key, child_value|
            yield(child_key, child_value.to_s)
            if key_so_far
              new_key = "#{key_so_far}_#{child_key}"
              key_values(new_key, child_value, &block)
            else
              key_values(child_key, child_value, &block) if child_value.is_a?(Hash) || child_value.is_a?(Array)
            end
          end
        elsif value.is_a?(Array)
          value.each do |child_value|
            key_values(key_so_far, child_value, &block)
          end
        else
          yield(key_so_far || "text", value.to_s)
        end
      end
    end
  end
end
