_ = require 'underscore'
{ fetchResources } = require './resourceutils'

# TODO:
# - JSDoc
# - make it util only
class States
  constructor: ->
    @key2id = {}
    @id2key = {}
    @duplicateKeys = []

  getAll: (client, projectKey) ->
    fetchResources(client, projectKey, 'states')

  buildMaps: (states) ->
    _.each states, (state) =>
      key = state.key
      id = state.id

      @id2key[id] = key

      if _.has @key2id, key
        @duplicateKeys.push key
      @key2id[key] = id


module.exports = States
