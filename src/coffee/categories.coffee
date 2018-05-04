_ = require 'underscore'
{ createRequestBuilder } = require '@commercetools/api-request-builder'
GLOBALS = require '../lib/globals'

# TODO:
# - JSDoc
# - make it util only
class Categories
  constructor: ->
    @id2index = {}
    @id2externalId = {}
    @id2slug = {}
    @name2id = {}
    @externalId2id = {}
    @fqName2id = {}
    @id2fqName = {}
    @duplicateNames = []

  getAll: (client, projectKey) ->
    service = createRequestBuilder {projectKey}
    request =
      uri: service.categories.build()
      method: 'GET'
    handler = (payload) -> Promise.resolve(payload)
    client.process request, handler, { accumulate: true }
      .then (response) ->
        response.reduce (acc, payload) ->
          acc.concat(payload.body.results)
        , []
  buildMaps: (categories) ->
    _.each categories, (category, index) =>
      name = category.name[GLOBALS.DEFAULT_LANGUAGE]
      id = category.id
      externalId = category.externalId
      @id2index[id] = index
      @id2slug[id] = category.slug[GLOBALS.DEFAULT_LANGUAGE]
      if _.has @name2id, name
        @duplicateNames.push name
      @name2id[name] = id
      @id2externalId[id] = externalId
      @externalId2id[externalId] = id

    _.each categories, (category, index) =>
      fqName = ''
      if category.ancestors
        _.each category.ancestors, (anchestor) =>
          cat = categories[@id2index[anchestor.id]]
          name = cat.name[GLOBALS.DEFAULT_LANGUAGE]
          fqName = "#{fqName}#{name}#{GLOBALS.DELIM_CATEGORY_CHILD}"
      fqName = "#{fqName}#{category.name[GLOBALS.DEFAULT_LANGUAGE]}"
      @fqName2id[fqName] = category.id
      @id2fqName[category.id] = fqName

module.exports = Categories
