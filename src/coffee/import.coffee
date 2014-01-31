_ = require 'underscore'
CONS = require '../lib/constants'
Validator = require '../lib/validator'
ProductSync = require('sphere-node-sync').ProductSync
CommonUpdater = require('sphere-node-sync').CommonUpdater
Q = require 'q'

class Import extends CommonUpdater

  constructor: (options = {}) ->
    super(options)
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
          @createOrUpdate products, @validator.types, callback
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
#    console.log "match %j", product
    index = @id2index[product.id] if product.id
    unless index
      index = @sku2index[product.masterVariant.sku] if product.masterVariant.sku
      unless index
        index = @slug2index[product.slug[CONS.DEFAULT_LANGUAGE] ] if product.slug[CONS.DEFAULT_LANGUAGE]
    return @existingProducts[index] if index > -1

  createOrUpdate: (products, types, callback) =>
    if _.size(products) is 0
      return @returnResult true, 'Nothing to do.', callback
    @initProgressBar 'Updating products', _.size(products)
    posts = []
    for product in products
      existingProduct = @match(product)
#      console.log "existingProduct %j", existingProduct
      if existingProduct
        posts.push @update(product, existingProduct, types)
      else
        posts.push @create(product)
    @processInBatches posts, callback

  processInBatches: (posts, callback, numberOfParallelRequest = 50, acc = []) =>
    current = _.take posts, numberOfParallelRequest
    Q.all(current).then (msg) =>
      messages = acc.concat(msg)
      if _.size(current) < numberOfParallelRequest
        @returnResult true, messages, callback
      else
        @processInBatches _.tail(posts, numberOfParallelRequest), callback, numberOfParallelRequest, messages
    .fail (msg) =>
      @returnResult false, msg, callback

  update: (product, existingProduct, types) ->
    deferred = Q.defer()
    allSameValueAttributes = types.id2SameForAllAttributes[product.productType.id]
    diff = @sync.buildActions(product, existingProduct, allSameValueAttributes)
    diff.update (error, response, body) =>
      @tickProgress()
      if error
        deferred.reject 'Error on updating product: ' + error
      else
        if response.statusCode is 200
          @publishProduct(JSON.parse(body)).then (msg) ->
            deferred.resolve 'Product updated.'
          .fail (msg) ->
            deferred.reject msg
        else if response.statusCode is 304
          deferred.resolve 'Product update not necessary.'
        else if response.statusCode is 400
          parsed = JSON.parse body
          humanReadable = JSON.stringify parsed, null, '  '
          deferred.resolve "Problem on updating product:\n" + humanReadable
        else
          deferred.reject 'Problem on updating product: ' + body
    deferred.promise

  create: (product) ->
    deferred = Q.defer()
    @rest.POST '/products', JSON.stringify(product), (error, response, body) =>
      @tickProgress()
      if error
        deferred.reject 'Error on creating new product: ' + error
      else
        if response.statusCode is 201
          @publishProduct(JSON.parse(body)).then (msg) ->
            deferred.resolve 'New product created.'
          .fail (msg) ->
            deferred.reject msg
        else if response.statusCode is 400
          parsed = JSON.parse body
          humanReadable = JSON.stringify parsed, null, '  '
          deferred.reject "Problem on creating new product:\n" + humanReadable
        else
          deferred.reject 'Problem on creating new product: ' + body
    deferred.promise

  publishProduct: (product, publish = true) ->
    deferred = Q.defer()
    unless @publishProducts
      deferred.resolve "Do not publish."
      return deferred.promise
    action = if publish then 'publish' else 'unpublish'
    data =
      id: product.id
      version: product.version
      actions: [
        action: action
      ]
    @rest.POST "/products/#{product.id}", JSON.stringify(data), (error, response, body) ->
      if error
        deferred.reject 'Error on publishing product: ' + error
      else
        if response.statusCode is 200
          deferred.resolve 'Product published.'
        else if response.statusCode is 400
          parsed = JSON.parse body
          humanReadable = JSON.stringify parsed, null, '  '
          deferred.reject "Problem on publishing product:\n" + humanReadable
        else
          deferred.reject 'Problem on publishing product: ' + body
    deferred.promise

  addExternalImages: (product) ->
    deferred = Q.defer()
    imageActions = @createExternalImageActions(product.masterVariant)
    for variant in product.variants
      imageActions = imageActions.concat(@createExternalImageActions(variant))
    if _.size(imageActions) is 0
      return deferred.resolve "No images."
    data =
      version: product.version
      actions: imageActions
    @rest.POST "/products/#{product.id}", JSON.stringify(date), (error, response, body) ->
      if error
        deferred.reject 'Error on adding external images to product: ' + error
      else
        if response.statusCode is 200
          deferred.resolve 'External images added.'
        else if response.statusCode is 400
          parsed = JSON.parse body
          humanReadable = JSON.stringify parsed, null, '  '
          deferred.reject "Problem on adding external images to product:\n" + humanReadable
        else
          deferred.reject 'Problem on adding external images to product: ' + body
    deferred.promise

  createExternalImageActions: (variant) ->
    actions = []
    return actions if _.size(variant.images) is 0
    for image in variant.images
      action =
        action: 'addExternalImage'
        variantId: variant.id
        image:
          url: image.url
#          dimensions:
#            w: image.dimensions.x
#            h: image.dimensions.y
#          label: image.label
      actions.push action

    actions


module.exports = Import