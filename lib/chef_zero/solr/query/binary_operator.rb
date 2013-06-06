module ChefZero
  module Solr
    module Query
      class BinaryOperator
        def initialize(left, operator, right)
          @left = left
          @operator = operator
          @right = right
        end

        def to_s
          "(#{left} #{operator} #{right})"
        end

        attr_reader :left
        attr_reader :operator
        attr_reader :right

        def matches_doc?(doc)
          case @operator
          when 'AND'
            left.matches_doc?(doc) && right.matches_doc?(doc)
          when 'OR'
            left.matches_doc?(doc) || right.matches_doc?(doc)
          when '^'
            left.matches_doc?(doc)
          when ':'
            if left.respond_to?(:literal_string) && left.literal_string
              values = doc[left.literal_string]
            else
              values = doc.matching_values { |key| left.matches_values?([key]) }
            end
            right.matches_values?(values)
          end
        end

        def matches_values?(values)
          case @operator
          when 'AND'
            left.matches_values?(values) && right.matches_values?(values)
          when 'OR'
            left.matches_values?(values) || right.matches_values?(values)
          when '^'
            left.matches_values?(values)
          when ':'
            raise ": does not work inside a : or term"
          end
        end
      end
    end
  end
end
