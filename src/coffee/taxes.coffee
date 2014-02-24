_ = require('underscore')._
Q = require 'q'


class Taxes
  constructor: ->
    @name2id = {}
    @duplicateNames = []

  getAll: (rest) ->
    deferred = Q.defer()
    rest.GET "/tax-categories?limit=0", (error, response, body) ->
      if error
        deferred.reject 'Error on getting tax categories: ' + error
      else if response.statusCode is 200
        taxCategories = body.results
        deferred.resolve taxCategories
      else if response.statusCode is 400
        humanReadable = JSON.stringify body, null, '  '
        deferred.resolve "Problem on getting tax categories:\n" + humanReadable
      else
        deferred.reject "Problem on getting tax categories:\n" +
        "status #{response.statusCode})\n" +
        "body " + response.body
    deferred.promise

  buildMaps: (taxCategories) ->
    for taxCat in taxCategories
      name = taxCat.name
      id = taxCat.id
      if _.has @name2id, name
        @duplicateNames.push name
      @name2id[name] = id


module.exports = Taxes
