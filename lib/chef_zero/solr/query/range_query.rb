module ChefZero
  module Solr
    module Query
      class RangeQuery
        def initialize(from, to, from_inclusive, to_inclusive)
          @from = from
          @to = to
          @from_inclusive = from_inclusive
          @to_inclusive = to_inclusive
        end

        def to_s
          "#{@from_inclusive ? '[' : '{'}#{@from} TO #{@to}#{@to_inclusive ? '[' : '{'}"
        end

        def matches?(key, value)
          case @from <=> value
          when -1
            return false
          when 0
            return false if !@from_inclusive
          end
          case @to <=> value
          when 1
            return false
          when 0
            return false if !@to_inclusive
          end
          return true
        end
      end
    end
  end
end
