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
    request =
      uri: service.productTypes.build()
      method: 'GET'
    handler = (payload) -> Promise.resolve(payload)
    client.process request, handler, { accumulate: true }
      .then (response) ->
        response.reduce (acc, payload) ->
          acc.concat(payload.body.results)
        , []

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
