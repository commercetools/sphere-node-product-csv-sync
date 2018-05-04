_ = require 'underscore'
{ fetchResources } = require './resourceutils'

# TODO:
# - JSDoc
# - make it util only
class Channels
  constructor: ->
    @key2id = {}
    @id2key = {}

  getAll: (client, projectKey) ->
    fetchResources(client, projectKey, 'channels')

  buildMaps: (channels) ->
    _.each channels, (channel) =>
      key = channel.key
      id = channel.id

      @key2id[key] = id
      @id2key[id] = key


module.exports = Channels
