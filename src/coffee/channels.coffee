_ = require 'underscore'
{ createRequestBuilder } = require '@commercetools/api-request-builder'

# TODO:
# - JSDoc
# - make it util only
class Channels
  constructor: ->
    @key2id = {}
    @id2key = {}

  getAll: (client, projectKey) ->
    service = createRequestBuilder {projectKey}
    request =
      uri: service.channels.build()
      method: 'GET'
    handler = (payload) -> Promise.resolve(payload)
    client.process request, handler, { accumulate: true }
      .then (response) ->
        response.reduce (acc, payload) ->
          acc.concat(payload.body.results)
        , []

  buildMaps: (channels) ->
    _.each channels, (channel) =>
      key = channel.key
      id = channel.id

      @key2id[key] = id
      @id2key[id] = key


module.exports = Channels
