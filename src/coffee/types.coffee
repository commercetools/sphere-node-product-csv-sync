_ = require('underscore')._
CONS = require '../lib/constants'
Q = require 'q'

class Types
  constructor: ->
    @id2index = {}
    @name2id = {}
    @duplicateNames = []
    @id2SameForAllAttributes = {}
    @id2nameAttributeDefMap = {}

  getAll: (rest) ->
    deferred = Q.defer()
    rest.GET "/product-types?limit=0", (error, response, body) ->
      if error
        deferred.reject 'Error on getting product types: ' + error
      else if response.statusCode isnt 200
        deferred.reject "Problem on getting product types:\n" +
          "status #{response.statusCode})\n" +
          "body " + response.body
      else
        productTypes = body.results
        deferred.resolve productTypes
    deferred.promise

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
