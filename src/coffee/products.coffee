_ = require 'underscore'
Q = require 'q'

class Products

  getAllExistingProducts: (rest, queryString = 'staged=true') ->
    deferred = Q.defer()

    console.log "QUERY", queryString

    process.stdout.write 'Fetching products '
    pageProducts = (offset = 0, limit = 100, total, acc = []) ->
      if total? and (offset + limit) >= total + limit
        console.log ' done'
        deferred.resolve acc
      else
        rest.GET "/product-projections?offset=#{offset}&limit=#{limit}&#{queryString}", (error, response, body) ->
          process.stdout.write "#{body.total} (#{limit} per .): " unless total
          process.stdout.write '.'
          if error
            deferred.reject 'Error on getting existing products: ' + error
          else
            if response.statusCode is 200
              pageProducts(offset + limit, limit, body.total, acc.concat(body.results))
            else
              humanReadable = JSON.stringify body, null, ' '
              deferred.reject 'Problem on getting existing products: ' + humanReadable

    pageProducts()

    deferred.promise

module.exports = Products
