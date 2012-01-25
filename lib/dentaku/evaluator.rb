require 'dentaku/token'
require 'dentaku/token_matcher'

module Dentaku
  class Evaluator
    T_NUMERIC    = TokenMatcher.new(:numeric)
    T_ADDSUB     = TokenMatcher.new(:operator, [:add, :subtract])
    T_MULDIV     = TokenMatcher.new(:operator, [:multiply, :divide])
    T_COMPARATOR = TokenMatcher.new(:comparator)
    T_OPEN       = TokenMatcher.new(:grouping, :open)
    T_CLOSE      = TokenMatcher.new(:grouping, :close)
    T_COMMA      = TokenMatcher.new(:grouping, :comma)
    T_NON_GROUP  = TokenMatcher.new(:grouping).invert
    T_LOGICAL    = TokenMatcher.new(:logical)
    T_COMBINATOR = TokenMatcher.new(:combinator)
    T_IF         = TokenMatcher.new(:function, :if)

    P_GROUP      = [T_OPEN,    T_NON_GROUP,  T_CLOSE]
    P_MATH_ADD   = [T_NUMERIC, T_ADDSUB,     T_NUMERIC]
    P_MATH_MUL   = [T_NUMERIC, T_MULDIV,     T_NUMERIC]
    P_COMPARISON = [T_NUMERIC, T_COMPARATOR, T_NUMERIC]
    P_COMBINE    = [T_LOGICAL, T_COMBINATOR, T_LOGICAL]

    P_IF         = [T_IF, T_OPEN, T_NON_GROUP, T_COMMA, T_NON_GROUP, T_COMMA, T_NON_GROUP, T_CLOSE]

    RULES = [
      [P_GROUP,      :evaluate_group],
      [P_MATH_MUL,   :apply],
      [P_MATH_ADD,   :apply],
      [P_COMPARISON, :apply],
      [P_COMBINE,    :apply],
      [P_IF,         :if],
    ]

    def evaluate(tokens)
      evaluate_token_stream(tokens).value
    end

    def evaluate_token_stream(tokens)
      while tokens.length > 1
        matched = false
        RULES.each do |pattern, evaluator|
          if pos = find_rule_match(pattern, tokens)
            tokens = evaluate_step(tokens, pos, pattern.length, evaluator)
            matched = true
            break
          end
        end

        raise "no rule matched #{ tokens.map(&:category).inspect }" unless matched
      end

      tokens << Token.new(:numeric, 0) if tokens.empty?

      tokens.first
    end

    def evaluate_step(token_stream, start, length, evaluator)
      expr = token_stream.slice!(start, length)
      token_stream.insert start, self.send(evaluator, *expr)
    end

    def find_rule_match(pattern, token_stream)
      position = 0
      while position <= token_stream.length - pattern.length
        substream = token_stream.slice(position, pattern.length)
        return position if pattern == substream
        position += 1
      end
      nil
    end

    def evaluate_group(*args)
      evaluate_token_stream(args[1..-2])
    end

    def apply(lvalue, operator, rvalue)
      l = lvalue.value
      r = rvalue.value

      case operator.value
      when :add      then Token.new(:numeric, l + r)
      when :subtract then Token.new(:numeric, l - r)
      when :multiply then Token.new(:numeric, l * r)
      when :divide   then Token.new(:numeric, l / r)

      when :le       then Token.new(:logical, l <= r)
      when :ge       then Token.new(:logical, l >= r)
      when :lt       then Token.new(:logical, l <  r)
      when :gt       then Token.new(:logical, l >  r)
      when :ne       then Token.new(:logical, l != r)
      when :eq       then Token.new(:logical, l == r)

      when :and      then Token.new(:logical, l && r)
      when :or       then Token.new(:logical, l || r)

      else
        raise "unknown comparator '#{ comparator }'"
      end
    end

    def if(*args)
      _, open, cond, _, true_value, _, false_value, close = args

      if evaluate_token_stream([cond])
        evaluate_token_stream([true_value])
      else
        evaluate_token_stream([false_value])
      end
    end
  end
end