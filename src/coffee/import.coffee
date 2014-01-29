_ = require 'underscore'
CONS = require '../lib/constants'
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
        if _.size(@validator.errors) isnt 0
          @returnResult false, @validator.map.errors, callback
          return
        products = []
        for rawProduct in @validator.rawProducts
          products.push @validator.map.mapProduct(rawProduct)
        if _.size(@validator.map.errors) isnt 0
          @returnResult false, @validator.map.errors, callback
          return
        @getAllExistingProducts().then (existingProducts) =>
          @initMatcher existingProducts
          @createOrUpdate products, callback
        .fail (msg) =>
          @returnResult false, msg, callback
      .fail (msg) =>
        @returnResult false, msg, callback

  getAllExistingProducts: ->
    deferred = Q.defer()
    @rest.GET '/product-projections?limit=0&staged=true', (error, response, body) ->
      if error
        deferred.reject 'Error on getting existing products: ' + error
      else
        if response.statusCode is 200
          deferred.resolve JSON.parse(body).results
        else
          deferred.reject 'Problem on getting existing products: ' + body
    deferred.promise

  initMatcher: (existingProducts) ->
    console.log "initMatcher: ", _.size existingProducts
    @existingProducts = existingProducts
    @id2index = {}
    @sku2index = {}
    @slug2index = {}
    for product, index in existingProducts
      @id2index[product.id] = index
      slug = product.slug[CONS.DEFAULT_LANGUAGE]
      @slug2index[slug] = index if slug
      mSku = @getSku(product.masterVariant)
      @sku2index[mSku] = index if mSku
      for variant in product.variants
        vSku = @getSku(variant)
        @sku2index[vSku] = index if vSku

    console.log "id2index: ", _.size @id2index
    console.log "sku2index: ", _.size @sku2index
    console.log "slug2index: ", _.size @slug2index

  getSku: (variant) ->
    variant.sku

  match: (product) ->
    console.log "match %j", product
    index = @id2index[product.id] if product.id
    unless index
      index = @sku2index[product.masterVariant.sku] if product.masterVariant.sku
      unless index
        index = @slug2index[product.slug[CONS.DEFAULT_LANGUAGE] ] if product.slug[CONS.DEFAULT_LANGUAGE]
    return @existingProducts[index] if index > -1

  createOrUpdate: (products, callback) ->
    if _.size(products) is 0
      return @returnResult true, 'Nothing to do.', callback
    posts = []
    for product in products
      existingProduct = @match(product)
      console.log "existingProduct %j", existingProduct
      if existingProduct
        posts.push @update(product, existingProduct)
      else
        posts.push @create(product)
#    @initProgressBar 'Updating products', _.size(posts)
    console.log 'Updating products', _.size(posts)
    Q.all(posts).then (msg) =>
      @returnResult true, msg, callback
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
        else if response.statusCode is 400
          # TODO: provide better feedback with error from response
          deferred.resolve "Problem on updating product: " + body
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
        else if response.statusCode is 400
          # TODO: provide better feedback with error from response
          deferred.reject "Problem on creating new product: " + body
        else
          deferred.reject 'Problem on creating new product: ' + body
    deferred.promise

module.exports = Import