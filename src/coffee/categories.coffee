_ = require('underscore')._
CONS = require '../lib/constants'
Q = require 'q'


class Categories
  constructor: ->
    @id2index = {}
    @name2id = {}
    @fqName2id = {}
    @duplicateNames = []

  getAll: (rest) ->
    deferred = Q.defer()
    rest.GET "/categories?limit=0", (error, response, body) ->
      if error
        deferred.reject 'Error on getting categories: ' + error
      else if response.statusCode isnt 200
        deferred.reject "Problem on getting categories:\n" +
          "status #{response.statusCode})\n" +
          "body " + response.body
      else
        categories = JSON.parse(body).results
        deferred.resolve categories
    deferred.promise

  buildMaps: (categories) ->
    for category, index in categories
      name = category.name[CONS.DEFAULT_LANGUAGE]
      id = category.id
      @id2index[id] = index
      if _.has @name2id, name
        @duplicateNames.push name
      @name2id[name] = id
    
    for category, index in categories
      fqName = ''
      if category.ancestors
        for anchestor in category.ancestors
          cat = categories[@id2index[anchestor.id]]
          name = cat.name[CONS.DEFAULT_LANGUAGE]
          fqName = "#{fqName}#{name}#{CONS.DELIM_CATEGORY_CHILD}"
      @fqName2id["#{fqName}#{category.name[CONS.DEFAULT_LANGUAGE]}"] = category.id


module.exports = Categories
