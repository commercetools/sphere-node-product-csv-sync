_ = require 'underscore'
{ fetchResources } = require './resourceutils'

# TODO:
# - JSDoc
# - make it util only
class Taxes
  constructor: ->
    @name2id = {}
    @id2name = {}
    @duplicateNames = []

  getAll: (client, projectKey) ->
    fetchResources(client, projectKey, 'taxCategories')

  buildMaps: (taxCategories) ->
    _.each taxCategories, (taxCat) =>
      name = taxCat.name
      id = taxCat.id

      @id2name[id] = name

      if _.has @name2id, name
        @duplicateNames.push name
      @name2id[name] = id


module.exports = Taxes
