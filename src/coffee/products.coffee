Q = require 'q'

class Products

  getAllExistingProducts: (rest, staged=false) ->
    deferred = Q.defer()
    rest.GET "/product-projections?limit=0&staged=#{staged}", (error, response, body) ->
      if error
        deferred.reject 'Error on getting existing products: ' + error
      else
        if response.statusCode is 200
          deferred.resolve JSON.parse(body).results
        else
          deferred.reject 'Problem on getting existing products: ' + body
    deferred.promise

module.exports = Products
