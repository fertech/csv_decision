CSV Decision
============

[![Gem Version](https://badge.fury.io/rb/csv_decision.svg)](https://badge.fury.io/rb/csv_decision)
[![Build Status](https://travis-ci.org/bpvickers/csv_decision.svg?branch=master)](https://travis-ci.org/bpvickers/csv_decision)
[![Coverage Status](https://coveralls.io/repos/github/bpvickers/csv_decision/badge.svg?branch=master)](https://coveralls.io/github/bpvickers/csv_decision?branch=master)
[![Maintainability](https://api.codeclimate.com/v1/badges/466a6c52e8f6a3840967/maintainability)](https://codeclimate.com/github/bpvickers/csv_decision/maintainability)
[![License](http://img.shields.io/badge/license-MIT-yellowgreen.svg)](#license)

### CSV based Ruby decision tables

`csv_decision` is a RubyGem for CSV based 
[decision tables](https://en.wikipedia.org/wiki/Decision_table). 
It accepts decision tables implemented as a 
[CSV file](https://en.wikipedia.org/wiki/Comma-separated_values), 
which can then be used to execute complex conditional logic against an input hash, 
producing a decision as an output hash.

### Why use `csv_decision`?
 
Typical "business logic" is notoriously illogical - full of corner cases and one-off 
exceptions. 
A decision table can express data-based decisions in a way that comes naturally 
to subject matter experts, who typically use spreadsheet models. 
Business logic can be encapsulated in a table, avoiding the need for tortuous conditional 
expressions.

This gem and the examples below take inspiration from 
[rufus/decision](https://github.com/jmettraux/rufus-decision).
(That gem is no longer maintained and CSV Decision has better 
decision-time performance, at the expense of slower table parse times and more memory -- 
see `benchmarks/rufus_decision.rb`.)
 
### Installation
 
To get started, just add `csv_decision` to your `Gemfile`, and then run `bundle`:
 
 ```ruby
 gem 'csv_decision'
 ```
 
 or simply
 ```bash
 gem install csv_decision
 ```
 
### Simple example
  
This table considers two input conditions: `topic` and `region`, labeled `in:`. 
Certain combinations yield an output value for `team_member`, labeled `out:`.
 
```
in:topic | in:region  | out:team_member
---------+------------+----------------
sports   | Europe     | Alice
sports   |            | Bob
finance  | America    | Charlie
finance  | Europe     | Donald
finance  |            | Ernest
politics | Asia       | Fujio
politics | America    | Gilbert
politics |            | Henry
         |            | Zach
```
 
When the topic is `finance` and the region is `Europe` the team member `Donald`
is selected. This is a "first match" decision table in that as soon as a match is made 
execution stops and a single output row (hash) is returned. 

The ordering of rows matters. `Ernest`, who is in charge of `finance` for the rest of 
the world, except for `America` and `Europe`, *must* come after his colleagues 
`Charlie` and `Donald`. `Zach` has been placed last, catching all the input combos
not matching any other row.

Here's the example as code:
 
 ```ruby
  # Valid CSV string
  data = <<~DATA
    in :topic, in :region,  out :team_member
    sports,    Europe,      Alice
    sports,    ,            Bob
    finance,   America,     Charlie
    finance,   Europe,      Donald
    finance,   ,            Ernest
    politics,  Asia,        Fujio
    politics,  America,     Gilbert
    politics,  ,            Henry
    ,          ,            Zach
  DATA

  table = CSVDecision.parse(data)
  
  table.decide(topic: 'finance', region: 'Europe') #=> { team_member: 'Donald' }
  table.decide(topic: 'sports', region: nil) #=> { team_member: 'Bob' }
  table.decide(topic: 'culture', region: 'America') #=> { team_member: 'Zach' }
```
 
An empty `in:` cell means "matches any value". 

Note that all column header names are symbolized, so it's actually more accurate to write 
`in :topic`; however spaces before and after the `:` do not matter.

If you have cloned this gem's git repo, then the example can also be run by loading
the table from a CSV file:
 
 ```ruby
table = CSVDecision.parse(Pathname('spec/data/valid/simple_example.csv'))
```
 
We can also load this same table using the option: `first_match: false`, which means that 
*all* matching rows will be accumulated into an array of hashes.
 
 ```ruby
table = CSVDecision.parse(data, first_match: false)
table.decide(topic: 'finance', region: 'Europe') #=> { team_member: %w[Donald Ernest Zach] }
```

For more examples see `spec/csv_decision/table_spec.rb`. 
Complete documentation of all table parameters is in the code - see 
`lib/csv_decision/parse.rb` and `lib/csv_decision/table.rb`.

### CSV Decision features
 * Either returns the first matching row as a hash (default), or accumulates all matches
 as an array of hashes (i.e., `parse` option `first_match: false` or CSV file option 
 `accumulate`).
 * Fast decision-time performance (see `benchmarks` folder). Automatically indexes all 
 constants-only columns that do not contain any empty strings.
 * In addition to strings, can match basic Ruby constants (e.g., `=nil`), 
 regular expressions (e.g., `=~ on|off`), comparisons (e.g., `> 100.0` ) and 
 Ruby-style ranges (e.g., `1..10`)
 * Can compare an input column versus another input hash key - e.g., `> :column`.
 * Any cell starting with `#` is treated as a comment, and comments may appear anywhere in 
 the table.
 * Column symbol expressions or Ruby methods (0-arity) may be used in input columns for 
 matching - e.g., `:column.zero?` or `:column == 0`.
 * May also use Ruby methods in output columns - e.g., `:column.length`.
 * Accepts data as a file, CSV string or an array of arrays.
  
#### Constants other than strings
Although `csv_decision` is string oriented, it does recognise other types of constant
present in the input hash. Specifically, the following classes are recognized: 
`Integer`, `BigDecimal`, `NilClass`, `TrueClass` and `FalseClass`. 

This is accomplished by prefixing the value with one of the operators `=`, `==` or `:=`. 
(The syntax is intentionally lax.)

For example:
 ```ruby
    data = <<~DATA
      in :constant, out :value
      :=nil,        :=nil
      ==false,      ==false
      =true,        =true
      = 0,          = 0
      :=100.0,      :=100.0
    DATA
          
  table = CSVDecision.parse(data)
  table.decide(constant: nil) # returns value: nil      
  table.decide(constant: 0) # returns value: 0        
  table.decide(constant: BigDecimal('100.0')) # returns value: BigDecimal('100.0')       
```
 
#### Column header symbols
All input and output column names are symbolized, and those symbols may be used to form 
simple expressions that refer to values in the input hash.

For example:
 ```ruby
    data = <<~DATA
      in :node, in :parent, out :top?
      ,         == :node,   yes
      ,         ,           no
    DATA
    
    table = CSVDecision.parse(data)
    table.decide(node: 0, parent: 0) # returns top?: 'yes'
    table.decide(node: 1, parent: 0) # returns top?: 'no'
 ```
 
Note that there is no need to include an input column for `:node` in the decision 
table - it just needs to be present in the input hash. The expression, `== :node` should be
read as `:parent == :node`. It can also be shortened to just `:node`, so the above decision 
table may be simplified to:

 ```ruby
    data = <<~DATA
      in :parent, out :top?
         :node,   yes
      ,           no
    DATA
 ```
These comparison operators are also supported: `!=`, `>`, `>=`, `<`, `<=`. 
In addition, you can also apply a Ruby 0-arity method - e.g., `.present?` or `.nil?`. Negation is
also supported - e.g., `!.nil?`. Note that `.nil?` can also be written as `:= nil?`, and `!.nil?`
as `:= !nil?`, depending on preference.

For more simple examples see `spec/csv_decision/examples_spec.rb`.

#### Input `guard` conditions
Sometimes it's more convenient to write guard expressions in a single column specialized for that purpose. 
For example:

```ruby
data = <<~DATA
  in :country, guard:,          out :ID, out :ID_type, out :len
  US,          :CUSIP.present?, :CUSIP,  CUSIP,        :ID.length
  GB,          :SEDOL.present?, :SEDOL,  SEDOL,        :ID.length
  ,            :ISIN.present?,  :ISIN,   ISIN,         :ID.length
  ,            :SEDOL.present?, :SEDOL,  SEDOL,        :ID.length
  ,            :CUSIP.present?, :CUSIP,  CUSIP,        :ID.length
  ,            ,                := nil,  := nil,       := nil
DATA

table = CSVDecision.parse(data)
table.decide(country: 'US',  CUSIP: '123456789') #=> { ID: '123456789', ID_type: 'CUSIP', len: 9 }
table.decide(country: 'EU',  CUSIP: '123456789', ISIN:'123456789012') 
  #=> { ID: '123456789012', ID_type: 'ISIN', len: 12 }
```
Input `guard:` columns may be anonymous, and must contain non-constant expressions. In addition to
0-arity Ruby methods, the following comparison operators are allowed: `==`, `!=`,
`>`, `>=`, `<` and `<=`. Also, regular expressions are supported - i.e., `=~` and `!~`.

#### Output `if` conditions
In some situations it is useful to apply filter conditions *after* all the output
columns have been derived. For example:

```ruby
data = <<~DATA
  in :country, guard:,          out :ID, out :ID_type, out :len,   if:
  US,          :CUSIP.present?, :CUSIP,  CUSIP8,       :ID.length, :len == 8
  US,          :CUSIP.present?, :CUSIP,  CUSIP9,       :ID.length, :len == 9
  US,          :CUSIP.present?, :CUSIP,  DUMMY,        :ID.length,
  ,            :ISIN.present?,  :ISIN,   ISIN,         :ID.length, :len == 12
  ,            :ISIN.present?,  :ISIN,   DUMMY,        :ID.length,
  ,            :CUSIP.present?, :CUSIP,  DUMMY,        :ID.length,
  DATA

table = CSVDecision.parse(data)
table.decide(country: 'US',  CUSIP: '123456789') #=> {ID: '123456789', ID_type: 'CUSIP9', len: 9}
table.decide(CUSIP: '12345678', ISIN:'1234567890') #=> {ID: '1234567890', ID_type: 'DUMMY', len: 10}
```
Output `if:` columns may be anonymous, and must contain non-constant expressions. In addition to
0-arity Ruby methods, the following comparison operators are allowed: `==`, `!=`,
`>`, `>=`, `<` and `<=`. Also, regular expressions are supported - i.e., `=~` and `!~`.
  
#### Input `set` columns

If you wish to set default values in the input hash, you can use a `set` column rather
than an `in` column. The data row beneath the header is used to specify the default expression.
There are three variations: `set` (unconditional default) `set/nil?`(set if `nil?` true) 
and `set/blank?` (set if `blank?` true). 
Note that the `decide!` method will mutate the input hash.

```ruby
data = <<~DATA
  set/nil? :country, guard:,          set: class,    out :PAID, out: len,     if:
  US,                ,                :class.upcase,
  US,                :CUSIP.present?, != PRIVATE,    :CUSIP,    :PAID.length, :len == 9
  !=US,              :ISIN.present?,  != PRIVATE,    :ISIN,     :PAID.length, :len == 12
  US,                :CUSIP.present?, PRIVATE,       :CUSIP,    :PAID.length,
  !=US,              :ISIN.present?,  PRIVATE,       :ISIN,     :PAID.length,
DATA

table = CSVDecision.parse(data)
table.decide(CUSIP: '1234567890', class: 'Private') #=> {PAID: '1234567890', len: 10}
table.decide(ISIN: '123456789012', country: 'GB', class: 'private') #=> {PAID: '123456789012', len: 12}

```

#### Input `path` columns

For hashes that contain sub-hashes, it's possible to specify a path for the purposes
of matching. (Arrays are currently not supported.)

```ruby
data = <<~DATA
  path:,   path:,    out :value
  header,  ,         :source_name
  header,  metrics,  :service_name
  payload, ,         :amount
  payload, ref_data, :account_id
DATA
table = CSVDecision.parse(data, first_match: false)

input = {
  header: { 
    id: 1, type_cd: 'BUY', source_name: 'Client', client_name: 'AAPL',
    metrics: { service_name: 'Trading', receive_time: '12:00' } 
  },
  payload: { 
    tran_id: 9, amount: '100.00',
    ref_data: { account_id: '5010', type_id: 'BUYL' } 
  }
}

table.decide(input) #=> { value: %w[Client Trading 100.00 5010] }
```

### Testing
 
 `csv_decision` includes thorough [RSpec](http://rspec.info) tests:
 
 ```bash
 # Execute within a clone of the csv_decision Git repository:
 bundle install
 rspec
 ```

### Planned features
 `csv_decision` is still a work in progress, and will be enhanced to support
 the following features:
 * Supply a pre-defined library of functions that may be called within input columns to 
   implement custom matching logic, or from the output columns to formulate the final 
   decision.
 * Built-in lookup functions evaluate other decision tables to implement guard conditions,
   or supply output values.
 * Available functions may be extended with a user-supplied library of Ruby methods 
   for custom logic.
 * Output columns may construct interpolated strings containing references to column 
   symbols.
 
### Reasons for the limitations of column expressions
The simple column expressions allowed by `csv_decision` are purposely limited for reasons of
understandability and maintainability. The whole point of this gem is to make decision rules
easier to express and comprehend as declarative, tabular logic.
While Ruby makes it easy to execute arbitrary code embedded within a CSV file, 
this could easily result in hard to debug logic that also poses safety risks.

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for a list of changes.

## License

CSV Decision &copy; 2017-2018 by [Brett Vickers](mailto:brett@phillips-vickers.com). 
CSV Decision is licensed under the MIT license. Please see the [LICENSE](./LICENSE) 
document for more information.