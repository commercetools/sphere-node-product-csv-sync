_ = require('underscore')._
CONS = require '../lib/constants'
Q = require 'q'

class Channels
  constructor: ->
    @key2id = {}
    @id2key = {}

  getAll: (rest) ->
    deferred = Q.defer()
    rest.GET "/channels?limit=0", (error, response, body) ->
      if error
        deferred.reject 'Error on getting channels: ' + error
      else if response.statusCode isnt 200
        deferred.reject "Problem on getting channels:\n" +
          "status #{response.statusCode})\n" +
          "body " + response.body
      else
        channels = body.results
        deferred.resolve channels
    deferred.promise

  buildMaps: (channels) ->
    for channel in channels
      key = channel.key
      id = channel.id
      @key2id[key] = id
      @id2key[id] = key


module.exports = Channels
