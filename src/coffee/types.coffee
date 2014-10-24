_ = require 'underscore'
CONS = require './constants'

# TODO:
# - JSDoc
# - make it util only
class Types
  constructor: ->
    @id2index = {}
    @name2id = {}
    @duplicateNames = []
    @id2SameForAllAttributes = {}
    @id2nameAttributeDefMap = {}

  getAll: (client) ->
    client.productTypes.all().fetch()

  buildMaps: (productTypes) ->
    for pt,index in productTypes
      name = pt.name
      id = pt.id
      @id2index[id] = index
      if _.has @name2id, name
        @duplicateNames.push name
      @name2id[name] = id
      @id2SameForAllAttributes[id] = []
      @id2nameAttributeDefMap[id] = {}
      continue unless pt.attributes
      for attribute in pt.attributes
        @id2SameForAllAttributes[id].push(attribute.name) if attribute.attributeConstraint is CONS.ATTRIBUTE_CONSTRAINT_SAME_FOR_ALL
        @id2nameAttributeDefMap[id][attribute.name] = attribute


module.exports = Types
