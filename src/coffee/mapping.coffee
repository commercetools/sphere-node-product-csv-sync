_ = require('underscore')._

class Mapping
  constructor: (options) ->

  map: (header, content, header2index) ->
    errors = []
    errors.concat(@valHeader csvContent)
    errors

  header2index: (header) ->
    _.object _.map header, (head, i) -> [head, i]

module.exports = Mapping
