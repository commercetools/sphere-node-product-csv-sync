_ = require('underscore')._
CONS = require '../lib/constants'
Q = require 'q'


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
    for category, index in categories
      name = category.name[CONS.DEFAULT_LANGUAGE]
      id = category.id
      @id2index[id] = index
      if _.has @name2id, name
        @duplicateNames.push name
      @name2id[name] = id
    
    for category, index in categories
      fqName = ''
      if category.ancestors
        for anchestor in category.ancestors
          cat = categories[@id2index[anchestor.id]]
          name = cat.name[CONS.DEFAULT_LANGUAGE]
          fqName = "#{fqName}#{name}#{CONS.DELIM_CATEGORY_CHILD}"
      fqName = "#{fqName}#{category.name[CONS.DEFAULT_LANGUAGE]}"
      @fqName2id[fqName] = category.id
      @id2fqName[category.id] = fqName

module.exports = Categories
