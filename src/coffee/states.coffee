_ = require 'underscore'
{ createRequestBuilder } = require '@commercetools/api-request-builder'

# TODO:
# - JSDoc
# - make it util only
class States
  constructor: ->
    @key2id = {}
    @id2key = {}
    @duplicateKeys = []

  getAll: (client, projectKey) ->
    service = createRequestBuilder {projectKey}
    request =
      uri: service.states.build()
      method: 'GET'
    handler = (payload) -> Promise.resolve(payload)
    client.process request, handler, { accumulate: true }
      .then (response) ->
        response.reduce (acc, payload) ->
          acc.concat(payload.body.results)
        , []

  buildMaps: (states) ->
    _.each states, (state) =>
      key = state.key
      id = state.id

      @id2key[id] = key

      if _.has @key2id, key
        @duplicateKeys.push key
      @key2id[key] = id


module.exports = States
