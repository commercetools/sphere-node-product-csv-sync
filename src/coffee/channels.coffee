# TODO:
# - JSDoc
# - make it util only
class Channels
  constructor: ->
    @key2id = {}
    @id2key = {}

  getAll: (client) ->
    client.channels.all().fetch()

  buildMaps: (channels) ->
    for channel in channels
      key = channel.key
      id = channel.id
      @key2id[key] = id
      @id2key[id] = key


module.exports = Channels
