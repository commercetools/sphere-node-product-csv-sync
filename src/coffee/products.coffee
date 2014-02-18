_ = require 'underscore'
Q = require 'q'

class Products

  getAllExistingProducts: (rest, staged, queryString = 'limit=0') ->
    deferred = Q.defer()
    if _.isString(queryString) and queryString.length > 0
      queryString += '&'
    queryString += "staged=#{staged}"
    console.log "#{queryString}"
    rest.GET "/product-projections?#{queryString}", (error, response, body) ->
      if error
        deferred.reject 'Error on getting existing products: ' + error
      else
        if response.statusCode is 200
          deferred.resolve JSON.parse(body).results
        else
          deferred.reject 'Problem on getting existing products: ' + body
    deferred.promise

module.exports = Products
