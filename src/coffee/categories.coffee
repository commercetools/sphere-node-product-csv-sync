_ = require 'underscore'
GLOBALS = require '../lib/globals'

# TODO:
# - JSDoc
# - make it util only
class Categories
  constructor: ->
    @id2index = {}
    @name2id = {}
    @fqName2id = {}
    @id2fqName = {}
    @duplicateNames = []

  getAll: (client) ->
    client.categories.all().fetch()

  buildMaps: (categories) ->
    _.each categories, (category, index) =>
      name = category.name[GLOBALS.DEFAULT_LANGUAGE]
      id = category.id
      @id2index[id] = index
      if _.has @name2id, name
        @duplicateNames.push name
      @name2id[name] = id

    _.each categories, (category, index) =>
      fqName = ''
      if category.ancestors
        _.each category.ancestors, (anchestor) =>
          cat = categories[@id2index[anchestor.id]]
          name = cat.name[GLOBALS.DEFAULT_LANGUAGE]
          fqName = "#{fqName}#{name}#{GLOBALS.DELIM_CATEGORY_CHILD}"
      fqName = "#{fqName}#{category.name[GLOBALS.DEFAULT_LANGUAGE]}"
      @fqName2id[fqName] = category.id
      @id2fqName[category.id] = fqName

module.exports = Categories
