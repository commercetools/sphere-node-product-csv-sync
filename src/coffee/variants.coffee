_ = require('underscore')._

class Variants

  constructor: ->
    @variantGroups = {}

  groupVariants: (rows, headerIndex) ->
    _.each rows, (row) =>
      value = row[headerIndex]
      if not _.has(@variantGroups, value)
        @variantGroups[value] = []
      @variantGroups[value].push row

    csv = []
    _.each @variantGroups, (group, key) ->
      variantId = 1
      _.each group, (value, key) ->
        value.push variantId
        csv.push value
        variantId = variantId + 1

    csv

module.exports = Variants