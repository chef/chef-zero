module ChefZero
  module Solr
    module Query
      class UnaryOperator
        def initialize(operator, operand)
          @operator = operator
          @operand = operand
        end

        def to_s
          "#{operator} #{operand}"
        end

        attr_reader :operator
        attr_reader :operand

        def matches_doc?(doc)
          case @operator
          when "-", "NOT", "!"
            !operand.matches_doc?(doc)
          when "+"
            # TODO This operator uses relevance to eliminate other, unrelated
            # expressions.  +a OR b means "if it has b but not a, don't return it"
            raise "+ not supported yet, because it is hard."
          end
        end

        def matches_values?(values)
          case @operator
          when "-", "NOT", "!"
            !operand.matches_values?(values)
          when "+"
            # TODO This operator uses relevance to eliminate other, unrelated
            # expressions.  +a OR b means "if it has b but not a, don't return it"
            raise "+ not supported yet, because it is hard."
          end
        end
      end
    end
  end
end
