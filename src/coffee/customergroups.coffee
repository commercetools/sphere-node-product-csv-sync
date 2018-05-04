_ = require 'underscore'
{ createRequestBuilder } = require '@commercetools/api-request-builder'

# TODO:
# - JSDoc
# - make it util only
class CustomerGroups
  constructor: ->
    @name2id = {}
    @id2name = {}

  getAll: (client, projectKey) ->
    service = createRequestBuilder {projectKey}
    request =
      uri: service.customerGroups.build()
      method: 'GET'
    handler = (payload) -> Promise.resolve(payload)
    client.process request, handler, { accumulate: true }
      .then (response) ->
        response.reduce (acc, payload) ->
          acc.concat(payload.body.results)
        , []

  buildMaps: (customerGroups) ->
    _.each customerGroups, (group) =>
      name = group.name
      id = group.id
      @name2id[name] = id
      @id2name[id] = name


module.exports = CustomerGroups
