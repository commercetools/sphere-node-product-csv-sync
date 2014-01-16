_ = require('underscore')._
Csv = require 'csv'
package_json = require '../package.json'

class Validator
  constructor: (options) ->

  parse: (csvString, callback) ->
    Csv().from.string(csvString)
    .to.array (data, count) ->
      callback data, count
    .on "error", (error) ->
      throw new Error error

  validate: (csv) ->
    errors = []
    errors

  valHeader: (csv) ->
    errors = []
    necessaryAttributes = [ 'productType', 'variantId' ]
    header = csv[0]
    remaining = _.difference necessaryAttributes, header
    if _.size(remaining) > 0
      for r in remaining
        errors.push "Can't find necessary header '#{r}'"
    errors

module.exports = Validator
