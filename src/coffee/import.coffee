_ = require 'underscore'
CONS = require '../lib/constants'
Validator = require '../lib/validator'
ProductSync = require('sphere-node-sync').ProductSync
Q = require 'q'
SphereClient = require 'sphere-node-client'

class Import

  constructor: (options = {}) ->
    @validator = new Validator options
    @sync = new ProductSync options
    @rest = @validator.rest
    @publishProducts = false
    @continueOnProblems = false
    @allowRemovalOfVariants = false
    @syncSeoAttributes = true
    @dryRun = false
    @client = new SphereClient options
    @blackListedCustomAttributesForUpdate = []

  import: (fileContent) ->
    deferred = Q.defer()
    @validator.parse fileContent, (data, count) =>
      console.log "CSV file with #{count} row(s) loaded."
      @validator.validate(data)
      .then (rawProducts) =>
        if _.size(@validator.errors) isnt 0
          deferred.reject @validator.errors
        else
          products = []
          console.log "Mapping #{_.size rawProducts} product(s) ..."
          for rawProduct in @validator.rawProducts
            products.push @validator.map.mapProduct(rawProduct)
          if _.size(@validator.map.errors) isnt 0
            deferred.reject @validator.map.errors
          else
            console.log "Mapping done. Fetching existing product(s) ..."
            @client.productProjections.staged().all().fetch()
            .then (result) =>
              existingProducts = result.body.results
              console.log "Comparing against #{_.size existingProducts} existing product(s) ..."
              @initMatcher existingProducts
              @createOrUpdate(products, @validator.types)
              .then (result) ->
                deferred.resolve result
      .fail (msg) ->
        deferred.reject msg
      .done()

    deferred.promise


  changeState: (publish = true, remove = false, filterFunction) ->
    deferred = Q.defer()
    @publishProducts = true
    @client.productProjections.staged(remove or publish).all().fetch()
    .then (result) =>
      existingProducts = result.body.results

      console.log "Found #{_.size existingProducts} product(s) ..."
      filteredProducts = _.filter existingProducts, filterFunction
      console.log "Filtered #{_.size filteredProducts} product(s)."

      if _.size(filteredProducts) is 0
        deferred.resolve 'Nothing to do.'
      else
        posts = _.map filteredProducts, (product) =>
          if remove
            @deleteProduct(product, 0)
          else
            @publishProduct(product, 0, publish)

        action = if publish then 'Publishing' else 'Unpublishing'
        action = 'Deleting' if remove
        console.log "#{action} #{_.size posts} product(s) ..."
        Q.all(posts)
    .then (result) ->
      deferred.resolve result
    .fail (msg) ->
      deferred.reject msg
    .done()

    deferred.promise

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
    #console.log "id2index", @id2index
    #console.log "sku2index", @sku2index
    #console.log "slug2index", @slug2index

  getSku: (variant) ->
    variant.sku

  match: (entry) ->
    product = entry.product
    index = @id2index[product.id] if product.id?
    unless index
      index = @sku2index[product.masterVariant.sku] if product.masterVariant.sku?
      if not index and (entry.header.has(CONS.HEADER_SLUG) or entry.header.hasLanguage(CONS.HEADER_SLUG))
        index = @slug2index[product.slug[CONS.DEFAULT_LANGUAGE]] if product.slug? and product.slug[CONS.DEFAULT_LANGUAGE]?
    return @existingProducts[index] if index > -1

  createOrUpdate: (products, types) =>
    if _.size(products) is 0
      Q.reject 'Nothing to do.'
    else
      # @initProgressBar 'Importing product(s)', _.size(products)
      posts = []
      for entry in products
        existingProduct = @match(entry)
        if existingProduct?
          posts.push @update(entry.product, existingProduct, types, entry.header, entry.rowIndex)
        else
          posts.push @create(entry.product, entry.rowIndex)

      Q.all posts

  _isBlackListedForUpdate: (attributeName) ->
    if _.isEmpty @blackListedCustomAttributesForUpdate
      false
    else
      _.contains @blackListedCustomAttributesForUpdate, attributeName

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
    if header.has(CONS.HEADER_PRICES)
      config.push { type: 'prices', group: 'white' }
    else
      config.push { type: 'prices', group: 'black' }
    if header.has(CONS.HEADER_IMAGES)
      config.push { type: 'images', group: 'white' }
    else
      config.push { type: 'images', group: 'black' }

    diff = @sync.config(config).buildActions(product, existingProduct, allSameValueAttributes)

    #console.log "DIFF %j", diff.get()
    filtered = diff.filterActions (action) =>
      #console.log "ACTION", action
      switch action.action
        when 'setAttribute', 'setAttributeInAllVariants' then (header.has(action.name) or header.hasLanguage(action.name)) and not @_isBlackListedForUpdate(action.name)
        when 'changeName' then header.has(CONS.HEADER_NAME) or header.hasLanguage(CONS.HEADER_NAME)
        when 'changeSlug' then header.has(CONS.HEADER_SLUG) or header.hasLanguage(CONS.HEADER_SLUG)
        when 'setDescription' then header.has(CONS.HEADER_DESCRIPTION) or header.hasLanguage(CONS.HEADER_DESCRIPTION)
        when 'setMetaAttributes' then @syncSeoAttributes
        when 'addToCategory', 'removeFromCategory' then header.has(CONS.HEADER_CATEGORIES)
        when 'setTaxCategory' then header.has(CONS.HEADER_TAX)
        when 'setSKU' then header.has(CONS.HEADER_SKU)
        when 'addVariant', 'addPrice', 'removePrice', 'changePrice', 'addExternalImage', 'removeImage' then true
        when 'removeVariant' then @allowRemovalOfVariants
        else throw Error "The action '#{action.action}' is not supported. Please contact the SPHERE.IO team!"

    if @dryRun
      updates = filtered.get()
      if updates?
        deferred.resolve "[row #{rowIndex}] DRY-RUN - updates for #{existingProduct.id}:\n#{_.prettify filtered.get()}"
      else
        deferred.resolve "[row #{rowIndex}] DRY-RUN - nothing to update."
    else
      filtered.update()
      .then (result) =>
        if result.statusCode is 304
          deferred.resolve "[row #{rowIndex}] Product update not necessary."
        else
          @publishProduct(result, rowIndex).then ->
            deferred.resolve "[row #{rowIndex}] Product updated."
      .fail (err) ->
        msg = "[row #{rowIndex}] Problem on updating product:\n#{_.prettify err}"
        if @continueOnProblems
          deferred.resolve "#{msg} - ignored!"
        else
          deferred.reject msg
      .done()

    deferred.promise

  create: (product, rowIndex) ->
    deferred = Q.defer()
    if @dryRun
      deferred.resolve "[row #{rowIndex}] DRY-RUN - create new product."
    else
      @client.products.create(product)
      .then (result) ->
        deferred.resolve "[row #{rowIndex}] New product created."
      .fail (err) ->
        if err.statusCode is 400
          msg = "[row #{rowIndex}] Problem on creating new product:\n#{_.prettify err}"
          if @continueOnProblems
            deferred.resolve "#{msg} - ignored!"
          else
            deferred.reject msg
        else
          deferred.reject "[row #{rowIndex}] Error on creating new product:\n#{_.prettify err}"
      .done()

    deferred.promise

  publishProduct: (product, rowIndex, publish = true) ->
    deferred = Q.defer()
    action = if publish then 'publish' else 'unpublish'
    if not @publishProducts
      deferred.resolve "Do not #{action}."
    else if publish and product.published and not product.hasStagedChanges
      deferred.resolve "[row #{rowIndex}] Product is already published - no staged changes."
    else
      data =
        id: product.id
        version: product.version
        actions: [
          action: action
        ]
      @client.products.byId(product.id).update(data)
      .then (result) ->
        deferred.resolve "[row #{rowIndex}] Product #{action}ed."
      .fail (err) ->
        if err.statusCode is 400
          if @continueOnProblems
            deferred.resolve "[row #{rowIndex}] Product is already #{action}ed."
          else
            deferred.reject "[row #{rowIndex}] Problem on #{action}ing product:\n#{_.prettify err}"
        else
          deferred.reject "[row #{rowIndex}] Error on #{action}ing product:\n#{_.prettify err}"
      .done()

    deferred.promise

  deleteProduct: (product, rowIndex) ->
    deferred = Q.defer()
    @client.products.byId(product.id).delete(product.version)
    .then ->
      deferred.resolve "[row #{rowIndex}] Product deleted."
    .fail (err) ->
      deferred.reject "[row #{rowIndex}] Error on deleting product:\n#{_.prettify err}"
    .done()

    deferred.promise


module.exports = Import
