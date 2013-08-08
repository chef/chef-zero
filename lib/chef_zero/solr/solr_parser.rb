require 'chef_zero/solr/query/binary_operator'
require 'chef_zero/solr/query/unary_operator'
require 'chef_zero/solr/query/term'
require 'chef_zero/solr/query/phrase'
require 'chef_zero/solr/query/range_query'
require 'chef_zero/solr/query/subquery'

module ChefZero
  module Solr
    class SolrParser
      def initialize(query_string)
        @query_string = query_string
        @index = 0
      end

      def parse
        read_expression
      end

      #
      # Tokenization
      #
      def peek_token
        @next_token ||= parse_token
      end

      def next_token
        result = peek_token
        @next_token = nil
        result
      end

      def parse_token
        # Skip whitespace
        skip_whitespace
        return nil if eof?

        # Operators
        operator = peek_operator_token
        if operator
          @index+=operator.length
          operator
        else
          # Everything that isn't whitespace or an operator, is part of a term
          # (characters plus backslashed escaped characters)
          start_index = @index
          begin
            if @query_string[@index] == '\\'
              @index+=1
            end
            @index+=1 if !eof?
          end while !eof? && peek_term_token
          @query_string[start_index..@index-1]
        end
      end

      def skip_whitespace
        if @query_string[@index] =~ /\s/
          whitespace = /\s+/.match(@query_string, @index) || peek
          @index += whitespace[0].length
        end
      end

      def peek_term_token
        return nil if @query_string[@index] =~ /\s/
        op = peek_operator_token
        return !op || op == '-'
      end

      def peek_operator_token
        if ['"', '+', '-', '!', '(', ')', '{', '}', '[', ']', '^', ':'].include?(@query_string[@index])
          return @query_string[@index]
        else
          result = @query_string[@index..@index+1]
          if ['&&', '||'].include?(result)
            return result
          end
        end
        nil
      end

      def eof?
        !@next_token && @index >= @query_string.length
      end

      # Parse tree creation
      def read_expression
        result = read_single_expression
        # Expression is over when we hit a close paren or eof
        # (peek_token has the side effect of skipping whitespace for us, so we
        # really know if we're at eof or not)
        until peek_token == ')' || eof?
          operator = peek_token
          if binary_operator?(operator)
            next_token
          else
            # If 2 terms are next to each other, the default operator is OR
            operator = 'OR'
          end
          next_expression = read_single_expression

          # Build the operator, taking precedence into account
          if result.is_a?(Query::BinaryOperator) &&
             binary_operator_precedence(operator) > binary_operator_precedence(result.operator)
            # a+b*c -> a+(b*c)
            new_right = Query::BinaryOperator.new(result.right, operator, next_expression)
            result = Query::BinaryOperator.new(result.left, result.operator, new_right)
          else
            # a*b+c -> (a*b)+c
            result = Query::BinaryOperator.new(result, operator, next_expression)
          end
        end
        result
      end

      def parse_error(token, str)
        raise "Error on token '#{token}' at #{@index} of '#{@query_string}': #{str}"
      end

      def read_single_expression
        token = next_token
        # If EOF, we have a problem Houston
        if !token
          parse_error(nil, "Expected expression!")

        # If it's an unary operand, build that
        elsif unary_operator?(token)
          operand = read_single_expression
          # TODO We rely on all unary operators having higher precedence than all
          # binary operators.  Check if this is the case.
          Query::UnaryOperator.new(token, operand)

        # If it's the start of a phrase, read the terms in the phrase
        elsif token == '"'
          # Read terms until close "
          phrase_terms = []
          until (term = next_token) == '"'
            phrase_terms << Query::Term.new(term)
          end
          Query::Phrase.new(phrase_terms)

        # If it's the start of a range query, build that
        elsif token == '{' || token == '['
          left = next_token
          parse_error(left, "Expected left term in range query") if !left
          to = next_token
          parse_error(left, "Expected TO in range query") if to != "TO"
          right = next_token
          parse_error(right, "Expected left term in range query") if !right
          end_range = next_token
          parse_error(right, "Expected end range '#{end_range}") if !['}', ']'].include?(end_range)
          Query::RangeQuery.new(left, right, token == '[', end_range == ']')

        elsif token == '('
          subquery = read_expression
          close_paren = next_token
          parse_error(close_paren, "Expected ')'") if close_paren != ')'
          Query::Subquery.new(subquery)

        # If it's the end of a closure, raise an exception
        elsif ['}',']',')'].include?(token)
          parse_error(token, "Unexpected end paren")

        # If it's a binary operator, raise an exception
        elsif binary_operator?(token)
          parse_error(token, "Unexpected binary operator")

        # Otherwise it's a term.
        else
          term = Query::Term.new(token)
          if peek_token == ':'
            Query::BinaryOperator.new(term, next_token, read_single_expression)
          else
            term
          end
        end
      end

      def unary_operator?(token)
        [ 'NOT', '+', '-' ].include?(token)
      end

      def binary_operator?(token)
        [ 'AND', 'OR', '^', ':'].include?(token)
      end

      def binary_operator_precedence(token)
        case token
        when '^'
          4
        when ':'
          3
        when 'AND'
          2
        when 'OR'
          1
        end
      end

      DEFAULT_FIELD = 'text'
    end
  end
end
