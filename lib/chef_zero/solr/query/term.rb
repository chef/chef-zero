require "chef_zero/solr/query/regexpable_query"

module ChefZero
  module Solr
    module Query
      class Term < RegexpableQuery
        def initialize(term)
          # Get rid of escape characters, turn * and ? into .* and . for regex, and
          # escape everything that needs escaping
          literal_string = ""
          regexp_string = ""
          index = 0
          while index < term.length
            if term[index] == "*"
              regexp_string << "#{WORD_CHARACTER}*"
              literal_string = nil
              index += 1
            elsif term[index] == "?"
              regexp_string << WORD_CHARACTER
              literal_string = nil
              index += 1
            elsif term[index] == "~"
              raise "~ unsupported"
            else
              if term[index] == '\\'
                index = index + 1
                if index >= term.length
                  raise "Backslash at end of string '#{term}'"
                end
              end
              literal_string << term[index] if literal_string
              regexp_string << Regexp.escape(term[index])
              index += 1
            end
          end
          super(regexp_string, literal_string)
        end

        def to_s
          "Term(#{regexp_string})"
        end
      end
    end
  end
end
