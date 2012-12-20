module ChefZero
  module Solr
    module Query
      class RegexpableQuery
        def initialize(regexp_string, literal_string)
          @regexp_string = regexp_string
          # Surround the regexp with word boundaries
          @regexp = Regexp.new("(^|#{NON_WORD_CHARACTER})#{regexp_string}($|#{NON_WORD_CHARACTER})", true)
          @literal_string = literal_string
        end

        attr_reader :literal_string
        attr_reader :regexp_string
        attr_reader :regexp

        def matches_doc?(doc)
          value = doc[DEFAULT_FIELD]
          return value ? matches_values?([value]) : false
        end
        def matches_values?(values)
          values.any? { |value| !@regexp.match(value).nil? }
        end

        WORD_CHARACTER = "[A-Za-z0-9@._':]"
        NON_WORD_CHARACTER = "[^A-Za-z0-9@._':]"
      end
    end
  end
end
