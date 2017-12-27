# frozen_string_literal: true

# CSV Decision: CSV based Ruby decision tables.
# Created December 2017.
# @author Brett Vickers <brett@phillips-vickers.com>
# See LICENSE and README.md for details.
module CSVDecision
  # Recognise guard column symbol expressions in input column data cells -
  # e.g., +> :column.present?+ or +:column == 100.0+.
  module Guard
    # Symbol guard expression - e.g., +> :column.present?+ or +:column == 100.0+.
    GUARD =
      "(?<negate>#{Matchers::NEGATE}?)\\s*" \
      ":(?<name>#{Header::COLUMN_NAME})\\s*" \
      "(?<method>#{Matchers::EQUALS}|!=|<|>|>=|<=|\\.)\\s*" \
      "(?<param>\\S.*)"
    private_constant :GUARD

    # Symbol comparision regular expression.
    GUARD_RE = Matchers.regexp(GUARD)
    private_constant :GUARD_RE

    # Negated method
    NEGATION = {
      '='  => '!=',
      '==' => '!=',
      ':=' => '!=',
      '.'  => '!.',
      '!=' => '=',
      '>'  => '<=',
      '>=' => '<',
      '<'  => '>=',
      '<=' => '>'
    }.freeze
    private_constant :NEGATION

    NUMERIC_COMPARE = {
      '=='  => proc { |symbol, value, hash| Matchers.numeric(hash[symbol])   == value },
      '!='  => proc { |symbol, value, hash| Matchers.numeric(hash[symbol])   != value },
      '>'   => proc { |symbol, value, hash| Matchers.numeric(hash[symbol]) &.>  value },
      '>='  => proc { |symbol, value, hash| Matchers.numeric(hash[symbol]) &.>= value },
      '<'   => proc { |symbol, value, hash| Matchers.numeric(hash[symbol]) &.<  value },
      '<='  => proc { |symbol, value, hash| Matchers.numeric(hash[symbol]) &.<= value }
    }.freeze
    private_constant :NUMERIC_COMPARE

    FUNCTION = {
      '.'  => proc { |symbol, value, hash|   hash[symbol].respond_to?(value) && hash[symbol].send(value) },
      '!.' => proc { |symbol, value, hash| !(hash[symbol].respond_to?(value) && hash[symbol].send(value)) },
    }.freeze
    private_constant :FUNCTION

    def self.compare?(lhs:, compare:, rhs:)
      # Is the rhs the same class or a superclass of lhs, and does rhs respond to the compare method?
      return lhs.send(compare, rhs) if lhs.is_a?(rhs.class) && rhs.respond_to?(compare)

      nil
    end
    private_class_method :compare?

    def self.non_numeric(method)
      proc = FUNCTION[method]
      return proc if proc

      return proc { |symbol, value, hash| compare?(lhs: hash[symbol], compare: method, rhs: value) }
    end

    def self.guard_proc(match)
      negate = match['negate'].present?
      method = match['method']
      method = negate ? NEGATION[method] : Matchers.normalize_operator(method)
      param =  match['param']

      # If the parameter is a numeric value then use numeric compares
      # rather than string compares.
      if (value = Matchers.to_numeric(param))
        proc = NUMERIC_COMPARE[method]
      else
        proc = non_numeric(method)
        value = param
      end

      [proc, value]
    end

    # (see Matchers::Matcher#matches?)
    def self.matches?(cell)
      match = GUARD_RE.match(cell)
      return false unless match

      proc, value = guard_proc(match)
      symbol = match['name'].to_sym
      Proc.with(type: :guard, function: proc.curry[symbol][value].freeze)
    end
  end
end