_ = require 'underscore'
CONS = require './constants'
{ createRequestBuilder } = require '@commercetools/api-request-builder'

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

  getAll: (client, projectKey) ->
    service = createRequestBuilder {projectKey}
    client.execute
      uri: service.productTypes.build()
      method: 'GET'

  buildMaps: (productTypes) ->
    _.each productTypes, (pt, index) =>
      name = pt.name
      id = pt.id

      @id2index[id] = index
      @id2SameForAllAttributes[id] = []
      @id2nameAttributeDefMap[id] = {}

      if _.has @name2id, name
        @duplicateNames.push name
      @name2id[name] = id

      pt.attributes or= []
      _.each pt.attributes, (attribute) =>
        @id2SameForAllAttributes[id].push(attribute.name) if attribute.attributeConstraint is CONS.ATTRIBUTE_CONSTRAINT_SAME_FOR_ALL
        @id2nameAttributeDefMap[id][attribute.name] = attribute


module.exports = Types
