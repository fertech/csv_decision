# frozen_string_literal: true

# CSV Decision: CSV based Ruby decision tables.
# Created December 2017.
# @author Brett Vickers <brett@phillips-vickers.com>
# See LICENSE and README.md for details.
module CSVDecision
  # Parse the input hash.
  # @api private
  module Input
    # @param (see Decide.decide)
    # @return [Hash{Symbol => Hash{Symbol=>Object}, Hash{Integer=>Object}}]
    #   Returns  a hash of two hashes:
    #   * hash: either a copy with keys symbolized or the original input object
    #   * scan_cols: Picks out the value in the input hash for each table input column.
    #     Defaults to nil if the key is missing in the input hash.
    def self.parse(table:, input:, symbolize_keys:)
      validate(input)

      parsed_input =
        parse_input(table: table, input: input(table, input, symbolize_keys))

      # We can freeze it as we made our own copy
      parsed_input[:hash].freeze if symbolize_keys

      parsed_input.freeze
    end

    def self.input(table, input, symbolize_keys)
      return input unless symbolize_keys

      # For safety the default is to symbolize the keys of a copy of the input hash.
      input = input.symbolize_keys
      input.slice!(*table.columns.input_keys)
      input
    end
    private_class_method :input

    def self.validate(input)
      return if input.is_a?(Hash) && !input.empty?
      raise ArgumentError, 'input must be a non-empty hash'
    end
    private_class_method :validate

    def self.parse_input(table:, input:)
      defaulted_columns = table.columns.defaults
      parse_cells(table: table, input: input) if defaulted_columns.empty?

      parse_defaulted(table: table, input: input, defaulted_columns: defaulted_columns)
    end
    private_class_method :parse_input

    def self.parse_cells(table:, input:)
      scan_cols = {}
      table.columns.ins.each_pair do |col, column|
        next if column.type == :guard

        scan_cols[col] = input[column.name]
      end

      { hash: input, scan_cols: scan_cols }
    end
    private_class_method :parse_cells

    def self.parse_defaulted(table:, input:, defaulted_columns:)
      scan_cols = {}

      table.columns.ins.each_pair do |col, column|
        next if column.type == :guard

        scan_cols[col] = default_value(cell: defaulted_columns[col], input: input, column: column)

        # Also update the input hash with the default value.
        input[column.name] = scan_cols[col]
      end

      { hash: input, scan_cols: scan_cols }
    end
    private_class_method :parse_defaulted

    def self.default_value(cell:, input:, column:)
      value = input[column.name]
      return value unless cell

      set_if = cell.set_if
      return value unless set_if == true || (value.respond_to?(set_if) && value.send(set_if))

      function = cell.function
      value = function.is_a?(::Proc) ? function[input] : function
      input[column.name] = value
    end
  end
end