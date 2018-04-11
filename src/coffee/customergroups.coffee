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
    client.execute
      uri: service.customerGroups.build()
      method: 'GET'

  buildMaps: (customerGroups) ->
    _.each customerGroups, (group) =>
      name = group.name
      id = group.id
      @name2id[name] = id
      @id2name[id] = name


module.exports = CustomerGroups
