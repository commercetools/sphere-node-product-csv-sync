{ createRequestBuilder } = require '@commercetools/api-request-builder'

exports.fetchResources = (client, projectKey, resource) ->
  service = createRequestBuilder { projectKey }
  request = {
    uri: service[resource].build()
    method: 'GET'
  }
  handler = (payload) -> Promise.resolve(payload)
  client.process request, handler, { accumulate: true }
    .then (response) ->
      response.reduce (acc, payload) ->
        acc.concat(payload.body.results)
      , []