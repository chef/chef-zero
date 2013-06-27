module ChefZero
  module Solr
    module Query
      class Subquery
        def initialize(subquery)
          @subquery = subquery
        end

        attr_reader :subquery

        def to_s
          "(#{subquery})"
        end

        def literal_string
          subquery.literal_string
        end

        def regexp
          subquery.regexp
        end

        def regexp_string
          subquery.regexp_string
        end

        def matches_doc?(doc)
          subquery.matches_doc?(doc)
        end

        def matches_values?(values)
          subquery.matches_values?(values)
        end
      end
    end
  end
end
