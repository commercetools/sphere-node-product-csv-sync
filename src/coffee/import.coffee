_ = require 'underscore'
Validator = require '../lib/validator'
ProductSync = require('sphere-node-sync').ProductSync
CommonUpdater = require('sphere-node-sync').CommonUpdater
Q = require 'q'

class Import extends CommonUpdater
  constructor: (options = {}) ->
    @validator = new Validator options
    @sync = new ProductSync options
    @rest = @validator.rest

  import: (fileContent, callback) ->
    @validator.parse fileContent, (data, count) =>
      @validator.validate(data).then (rawProducts) =>
        products = []
        for rawProduct in @validator.rawProducts
          products.push @validator.map.mapProduct(rawProduct)
        @createOrUpdate products, callback
      .fail (msg) ->
        @returnResult false, msg, callback

  match: (product) ->
    # for now only create new products

  createOrUpdate: (products, callback) ->
    if _.size(products) is 0
      return @returnResult true, 'Nothing to do.', callback
    posts = []
    for product in products
      existingProduct = @match(product)
      if existingProduct
        posts.push @update(product, existingProduct)
      else
        posts.push @create(product)
#    @initProgressBar 'Updating products', _.size(posts)
    Q.all(posts).then (messages) =>
      @returnResult true, messages, callback
    .fail (msg) =>
      @returnResult false, msg, callback

  update: (products, existingProduct) ->
    deferred = Q.defer()
    @sync.buildActions(products, existingProduct).update (error, response, body) ->
#      @tickProgress()
      if error
        deferred.reject 'Error on updating product: ' + error
      else
        if response.statusCode is 200
          deferred.resolve 'Product updated.'
        else if response.statusCode is 304
          deferred.resolve 'Product update not necessary.'
        else
          deferred.reject 'Problem on updating product: ' + body
    deferred.promise

  create: (product) ->
    deferred = Q.defer()
    @rest.POST '/products', JSON.stringify(product), (error, response, body) ->
#      @tickProgress()
      if error
        deferred.reject 'Error on creating new product: ' + error
      else
        if response.statusCode is 201
          deferred.resolve 'New product created.'
        else
          deferred.reject 'Problem on creating new product: ' + body
    deferred.promise

module.exports = Import