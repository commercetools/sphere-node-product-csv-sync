_ = require 'underscore'
CONS = require '../lib/constants'
Validator = require '../lib/validator'
Products = require '../lib/products'
ProductSync = require('sphere-node-sync').ProductSync
CommonUpdater = require('sphere-node-sync').CommonUpdater
Q = require 'q'

class Import extends CommonUpdater

  constructor: (options = {}) ->
    super(options)
    @validator = new Validator options
    @sync = new ProductSync options
    @rest = @validator.rest
    @productService = new Products()
    @publishProducts = false
    @continueOnProblems = false
    @allowRemovalOfVariants = false

  import: (fileContent, callback) ->
    @validator.parse fileContent, (data, count) =>
      console.log "CSV file with #{count} row(s) loaded."
      @validator.validate(data).then (rawProducts) =>
        if _.size(@validator.errors) isnt 0
          @returnResult false, @validator.map.errors, callback
          return
        products = []
        console.log "Mapping #{_.size rawProducts} product(s) ..."
        for rawProduct in @validator.rawProducts
          products.push @validator.map.mapProduct(rawProduct)
        if _.size(@validator.map.errors) isnt 0
          @returnResult false, @validator.map.errors, callback
          return
        console.log "Mapping done. Fetching existing product(s) ..."
        @productService.getAllExistingProducts(@rest).then (existingProducts) =>
          console.log "Comparing against #{_.size existingProducts} existing product(s) ..."
          @initMatcher existingProducts
          @createOrUpdate products, @validator.types, callback
        .fail (msg) =>
          #console.log "ERR1", msg
          @returnResult false, msg, callback
        .done()
      .fail (msg) =>
        #console.log "ERR2", msg
        @returnResult false, msg, callback

  changeState: (publish = true, remove = false, filterFunction, callback) ->
    @publishProducts = true
    action = if publish then 'publish' else 'unpublish'
    action = 'delete' if remove
    @productService.getAllExistingProducts(@rest, "staged=#{publish}").then (existingProducts) =>

      console.log "Found #{_.size existingProducts} product(s) ..."
      filteredProducts = _.filter existingProducts, filterFunction
      console.log "Filtered products #{_.size filteredProducts}"

      if _.size(filteredProducts) is 0
        @returnResult true, 'Nothing to do', callback
      else
        posts = _.map filteredProducts, (product) =>
          if remove
            @deleteProduct(product, 0)
          else
            @publishProduct(product, 0, publish)

        console.log "#{action}ing #{_.size posts} product(s) ..."
        @processInBatches posts, callback
    .fail (msg) =>
      @returnResult false, msg, callback
    .done()

  initMatcher: (existingProducts) ->
    @existingProducts = existingProducts
    @id2index = {}
    @sku2index = {}
    @slug2index = {}
    for product, index in existingProducts
      @id2index[product.id] = index
      if product.slug?
        slug = product.slug[CONS.DEFAULT_LANGUAGE]
        @slug2index[slug] = index if slug?

      mSku = @getSku(product.masterVariant)
      @sku2index[mSku] = index if mSku?
      for variant in product.variants
        vSku = @getSku(variant)
        @sku2index[vSku] = index if vSku?

  getSku: (variant) ->
    variant.sku

  match: (product) ->
    index = @id2index[product.id] if product.id?
    unless index
      index = @sku2index[product.masterVariant.sku] if product.masterVariant.sku?
      unless index
        index = @slug2index[product.slug[CONS.DEFAULT_LANGUAGE]] if product.slug? and product.slug[CONS.DEFAULT_LANGUAGE]?
    return @existingProducts[index] if index > -1

  createOrUpdate: (products, types, callback) =>
    if _.size(products) is 0
      return @returnResult true, 'Nothing to do.', callback
    @initProgressBar 'Importing product(s)', _.size(products)
    posts = []
    for entry in products
      existingProduct = @match(entry.product)
      if existingProduct?
        posts.push @update(entry.product, existingProduct, types, entry.header, entry.rowIndex)
      else
        posts.push @create(entry.product, entry.rowIndex)
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

  update: (product, existingProduct, types, header, rowIndex) ->
    deferred = Q.defer()
    allSameValueAttributes = types.id2SameForAllAttributes[product.productType.id]
    config = [
      { type: 'base', group: 'white' }
      { type: 'references', group: 'white' }
      { type: 'attributes', group: 'white' }
      { type: 'variants', group: 'white' }
      { type: 'metaAttributes', group: 'white' }
    ]
    config.push { type: 'prices', group: 'black' } unless header.has(CONS.HEADER_PRICES)
    config.push { type: 'images', group: 'black' } unless header.has(CONS.HEADER_IMAGES)

    diff = @sync.config(config).buildActions(product, existingProduct, allSameValueAttributes)

    #console.log "DIFF %j", diff.get()
    filtered = diff.filterActions (action) =>
      #console.log "ACTION", action
      switch action.action
        when 'setAttribute', 'setAttributeInAllVariants' then header.has(action.name) or header.hasLanguage(action.name)
        when 'changeName' then header.has(CONS.HEADER_NAME) or header.hasLanguage(CONS.HEADER_NAME)
        when 'changeSlug' then header.has(CONS.HEADER_SLUG) or header.hasLanguage(CONS.HEADER_SLUG)
        when 'setDescription' then header.has(CONS.HEADER_DESCRIPTION) or header.hasLanguage(CONS.HEADER_DESCRIPTION)
        when 'setMetaAttributes' then true # TODO: Find out which attribute actually changed, which header is present and then modify action.
        when 'addToCategory', 'removeFromCategory' then header.has(CONS.HEADER_CATEGORIES)
        when 'setTaxCategory' then header.has(CONS.HEADER_TAX)
        when 'setSKU' then header.has(CONS.HEADER_SKU)
        when 'addVariant', 'addPrice', 'removePrice', 'changePrice', 'addExternalImage', 'removeImage' then true
        when 'removeVariant' then @allowRemovalOfVariants
        else throw Error "The action '#{action.action}' is not supported. Please contact the SPHERE.IO team!"

    #console.log "FILTERED %j", filtered.get()

    filtered.update (error, response, body) =>
      @tickProgress()
      if error?
        deferred.reject "[row #{rowIndex}] Error on updating product: " + error
      else
        if response.statusCode is 200
          @publishProduct(body, rowIndex).then (msg) ->
            deferred.resolve "[row #{rowIndex}] Product updated."
          .fail (msg) ->
            deferred.reject msg
        else if response.statusCode is 304
          deferred.resolve "[row #{rowIndex}] Product update not necessary."
        else if response.statusCode is 400
          humanReadable = JSON.stringify body, null, ' '
          msg = "[row #{rowIndex}] Problem on updating product:\n" + humanReadable
          if @continueOnProblems
            deferred.resolve msg
          else
            deferred.reject msg

        else
          humanReadable = JSON.stringify body, null, ' '
          deferred.reject "[row #{rowIndex}] Error on updating product: " + humanReadable

    deferred.promise

  create: (product, rowIndex) ->
    deferred = Q.defer()
    @rest.POST '/products', JSON.stringify(product), (error, response, body) =>
      @tickProgress()
      if error?
        deferred.reject "[row #{rowIndex}] Error on creating new product: " + error
      else
        if response.statusCode is 201
          @publishProduct(body, rowIndex).then (msg) ->
            deferred.resolve "[row #{rowIndex}] New product created."
          .fail (msg) ->
            deferred.reject msg
        else if response.statusCode is 400
          humanReadable = JSON.stringify body, null, ' '
          msg = "[row #{rowIndex}] Problem on creating new product:\n" + humanReadable
          if @continueOnProblems
            deferred.resolve msg
          else
            deferred.reject msg
        else
          humanReadable = JSON.stringify body, null, ' '
          deferred.reject "[row #{rowIndex}] Error on creating new product: " + humanReadable

    deferred.promise

  publishProduct: (product, rowIndex, publish = true) ->
    deferred = Q.defer()
    action = if publish then 'publish' else 'unpublish'
    unless @publishProducts
      deferred.resolve "Do not #{action}."
    else if publish and product.published and not product.hasStagedChanges
      deferred.resolve "Product is already published"
    else
      data =
        id: product.id
        version: product.version
        actions: [
          action: action
        ]
      @rest.POST "/products/#{product.id}", JSON.stringify(data), (error, response, body) ->
        if error?
          deferred.reject "[row #{rowIndex}] Error on #{action}ing product: " + error
        else
          if response.statusCode is 200
            deferred.resolve "[row #{rowIndex}] Product #{action}ed."
          else if response.statusCode is 400
            if @continueOnProblems
              deferred.resolve "[row #{rowIndex}] Product is already #{action}ed."
            else
              humanReadable = JSON.stringify body, null, ' '
              deferred.reject "[row #{rowIndex}] Problem on #{action}ing product:\n" + humanReadable
          else
            humanReadable = JSON.stringify body, null, ' '
            deferred.reject "[row #{rowIndex}] Problem on #{action}ing product (code #{response.statusCode}): " + humanReadable

    deferred.promise

  deleteProduct: (product, rowIndex) ->
    deferred = Q.defer()
    @rest.DELETE "/products/#{product.id}?version=#{product.version}", (error, response, body) ->
      if error?
        deferred.reject "[row #{rowIndex}] Error on deleting product: " + error
      else
        if response.statusCode is 200
          deferred.resolve "[row #{rowIndex}] Product deleted."
        else
          humanReadable = JSON.stringify body, null, ' '
          deferred.reject "[row #{rowIndex}] Problem on deleting product (code #{response.statusCode}): " + humanReadable
    deferred.promise


module.exports = Import
