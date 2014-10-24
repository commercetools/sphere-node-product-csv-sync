_ = require 'underscore'

# TODO:
# - JSDoc
# - make it util only
class Taxes
  constructor: ->
    @name2id = {}
    @id2name = {}
    @duplicateNames = []

  getAll: (client) ->
    client.taxCategories.all().fetch()

  buildMaps: (taxCategories) ->
    for taxCat in taxCategories
      name = taxCat.name
      id = taxCat.id
      if _.has @name2id, name
        @duplicateNames.push name
      @name2id[name] = id
      @id2name[id] = name


module.exports = Taxes
