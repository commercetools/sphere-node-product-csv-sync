_ = require 'underscore'
Q = require 'q'

class Products

  getAllExistingProducts: (rest, queryString = 'staged=true&limit=0') ->
    deferred = Q.defer()
    rest.GET "/product-projections?#{queryString}", (error, response, body) ->
      if error
        deferred.reject 'Error on getting existing products: ' + error
      else
        if response.statusCode is 200
          deferred.resolve body.results
        else
          deferred.reject 'Problem on getting existing products: ' + body
    deferred.promise

module.exports = Products
