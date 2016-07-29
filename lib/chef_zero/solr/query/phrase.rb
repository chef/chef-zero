require "chef_zero/solr/query/regexpable_query"

module ChefZero
  module Solr
    module Query
      class Phrase < RegexpableQuery
        def initialize(terms)
          # Phrase is terms separated by whitespace
          if terms.size == 0 && terms[0].literal_string
            literal_string = terms[0].literal_string
          else
            literal_string = nil
          end
          super(terms.map { |term| term.regexp_string }.join("#{NON_WORD_CHARACTER}+"), literal_string)
        end

        def to_s
          "Phrase(\"#{@regexp_string}\")"
        end
      end
    end
  end
end
