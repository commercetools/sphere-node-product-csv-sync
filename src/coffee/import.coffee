_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'
{SphereClient, ProductSync, Errors} = require 'sphere-node-sdk'
{Repeater} = require 'sphere-node-utils'
CONS = require './constants'
GLOBALS = require './globals'
Validator = require './validator'

# TODO:
# - better organize subcommands / classes / helpers
# - don't save partial results globally, instead pass them around to functions that need them
# - JSDoc
class Import

  constructor: (options = {}) ->
    if options.config #for easier unit testing
      @client = new SphereClient options
      @client.setMaxParallel 10
      @sync = new ProductSync
      @repeater = new Repeater attempts: 3

    @validator = new Validator options

    # TODO: define globale options variable object
    @publishProducts = false
    @continueOnProblems = options.continueOnProblems
    @allowRemovalOfVariants = false
    @updatesOnly = false
    @dryRun = false
    @blackListedCustomAttributesForUpdate = []
    @customAttributeNameToMatch = undefined
    @matchBy = 'id'

  # current workflow:
  # - parse csv
  # - validate csv
  # - map all parsed products
  # - get all existing products
  # - create/update products based on matches
  #
  # ideally workflow:
  # - get all product types, categories, customer groups, taxes, channels (maybe get them ondemand?)
  # - stream csv -> chunk (100)
  # - base csv validation of chunk
  # - map products to json in chunk
  # - lookup mapped products in sphere (depending on given matcher - id, sku, slug, custom attribute)
  # - validate products against their product types (we might not have to product type before)
  # - create/update products based on matches
  # - next chunk
  import: (fileContent) ->
    @validator.parse fileContent
    .then (parsed) =>
      console.log "CSV file with #{parsed.count} row(s) loaded."
      @validator.validate(parsed.data)
      .then (rawProducts) =>
        if _.size(@validator.errors) isnt 0
          Promise.reject @validator.errors
        else
          # TODO:
          # - process products in batches!!
          # - for each chunk match products -> createOrUpdate
          # - provide a way to accumulate partial results, or just log them to console
          console.log "Mapping #{_.size rawProducts} product(s) ..."
          # for rawProduct in rawProducts
          #   products.push @validator.map.mapProduct(rawProduct)
          products = rawProducts.map((p) => @validator.map.mapProduct p)
          if _.size(@validator.map.errors) isnt 0
            Promise.reject @validator.map.errors
          chunks = _.batchList(products, 20)
          p = (p) => @processProducts(p)
          Promise.map(chunks, p, { concurrency: 20 })
          .then((results) => results.reduce((agg, r) => agg.concat(r) []))

  processProducts: (products) ->
    console.log "Mapping done. About to process existing product(s) ..."
    @_mapMatchFunction(@matchBy)(@client.productProjections, products)
    .then (payload) =>
      existingProducts = payload.body.results
      console.log "Comparing against #{payload.body.total} existing product(s) ..."
      @initMatcher existingProducts
      productsToUpdate =
      if @validator.updateVariantsOnly
        @mapVariantsBasedOnSKUs existingProducts, products
      else
        products
      console.log "Processing #{_.size productsToUpdate} product(s) ..."
      @createOrUpdate(productsToUpdate, @validator.types)
    .then (result) ->
      # TODO: resolve with a summary of the import
      console.log "Finished processing #{_.size result} product(s)"
      Promise.resolve result

  _mapMatchFunction: (matchBy) ->
    switch matchBy
      when 'id' then @_matchById

  # Matches products by `id` attribute
  # @param {Array} products
  _matchById: (service, products) ->
    ids = products.map((p) -> "\"#{p.product.id}\"").join(',')
    service.staged().filter("id:in (#{ids})").fetch()

  _createProductFetchBySkuQueryPredicate: (skus) ->
    skuString = "sku in (\"#{skus.join('", "')}\")"
    return "masterVariant(#{skuString}) or variants(#{skuString})"

  changeState: (publish = true, remove = false, filterFunction) ->
    @publishProducts = true

    @client.productProjections.staged(remove or publish).perPage(500).process (result) =>
      existingProducts = result.body.results

      console.log "Found #{_.size existingProducts} product(s) ..."
      filteredProducts = _.filter existingProducts, filterFunction
      console.log "Filtered #{_.size filteredProducts} product(s)."

      if _.size(filteredProducts) is 0
        # Q 'Nothing to do.'
        Promise.resolve()
      else
        posts = _.map filteredProducts, (product) =>
          if remove
            @deleteProduct(product, 0)
          else
            @publishProduct(product, 0, publish)

        action = if publish then 'Publishing' else 'Unpublishing'
        action = 'Deleting' if remove
        console.log "#{action} #{_.size posts} product(s) ..."
        Promise.all(posts)
    .then (result) ->
      filteredResult = _.filter result, (r) -> r
      # TODO: resolve with a summary of the import
      console.log "Finished processing #{_.size filteredResult} products"
      if _.size(filteredResult) is 0
        Promise.resolve 'Nothing to do'
      else
        Promise.resolve filteredResult

  initMatcher: (existingProducts) ->
    @existingProducts = existingProducts
    @id2index = {}
    @customAttributeValue2index = {}
    @sku2index = {}
    @sku2variantInfo = {}
    @slug2index = {}
    _.each existingProducts, (product, productIndex) =>
      @id2index[product.id] = productIndex
      if product.slug?
        slug = product.slug[GLOBALS.DEFAULT_LANGUAGE]
        @slug2index[slug] = productIndex if slug?

      product.variants or= []
      variants = [product.masterVariant].concat(product.variants)

      _.each variants, (variant, variantIndex) =>
        sku = variant.sku
        if sku?
          @sku2index[sku] = productIndex
          @sku2variantInfo[sku] =
            index: variantIndex - 1 # we reduce by one because of the masterVariant
            id: variant.id
        @customAttributeValue2index[@getCustomAttributeValue variant] = productIndex if @customAttributeNameToMatch?

    #console.log "id2index", @id2index
    #console.log "customAttributeValue2index", @customAttributeValue2index
    #console.log "sku2index", @sku2index
    #console.log "slug2index", @slug2index
    #console.log "sku2variantInfo", @sku2variantInfo

  mapVariantsBasedOnSKUs: (existingProducts, products) ->
    console.log "Mapping variants for #{_.size products} product type(s) ..."
    productsToUpdate = {}
    _.each products, (entry) =>
      _.each entry.product.variants, (variant) =>
        productIndex = @sku2index[variant.sku]
        if productIndex?
          existingProduct = productsToUpdate[productIndex]?.product or _.deepClone existingProducts[productIndex]
          variantInfo = @sku2variantInfo[variant.sku]
          variant.id = variantInfo.id
          if variant.id is 1
            existingProduct.masterVariant = variant
          else
            existingProduct.variants[variantInfo.index] = variant
          productsToUpdate[productIndex] =
            product: existingProduct
            header: entry.header
            rowIndex: entry.rowIndex
        else
          console.warn "Ignoring variant as no match by SKU found for: ", variant
    _.map productsToUpdate

  getCustomAttributeValue: (variant) ->
    variant.attributes or= []
    attrib = _.find variant.attributes, (attribute) =>
      attribute.name is @customAttributeNameToMatch
    attrib?.value

  match: (entry) ->
    product = entry.product
    # 1. match by id
    index = @id2index[product.id] if product.id?
    if not index
      # 2. match by custom attribute
      index = @_matchOnCustomAttribute product
    if not index
      # 3. match by sku
      index = @sku2index[product.masterVariant.sku] if product.masterVariant.sku?
    if not index and (entry.header.has(CONS.HEADER_SLUG) or entry.header.hasLanguageForBaseAttribute(CONS.HEADER_SLUG))
      # 4. match by slug (if header is present)
      index = @slug2index[product.slug[GLOBALS.DEFAULT_LANGUAGE]] if product.slug? and product.slug[GLOBALS.DEFAULT_LANGUAGE]?

    return @existingProducts[index] if index > -1

  _matchOnCustomAttribute: (product) ->
    attribute = undefined
    if @customAttributeNameToMatch?
      product.variants or= []
      variants = [product.masterVariant].concat(product.variants)
      _.find variants, (variant) =>
        variant.attributes or= []
        attribute = _.find variant.attributes, (attrib) =>
          attrib.name is @customAttributeNameToMatch
        attribute?

    if attribute?
      @customAttributeValue2index[attribute.value]

  createOrUpdate: (products, types) ->
    Promise.all _.map products, (entry) =>
      @repeater.execute =>
        existingProduct = @match(entry)
        if existingProduct?
          @update(entry.product, existingProduct, types, entry.header, entry.rowIndex)
        else
          @create(entry.product, entry.rowIndex)
      , (e) ->
        if e.code is 504
          console.warn 'Got a timeout, will retry again...'
          Promise.resolve() # will retry in case of Gateway Timeout
        else
          Promise.reject e


  _isBlackListedForUpdate: (attributeName) ->
    if _.isEmpty @blackListedCustomAttributesForUpdate
      false
    else
      _.contains @blackListedCustomAttributesForUpdate, attributeName

  update: (product, existingProduct, types, header, rowIndex) ->
    allSameValueAttributes = types.id2SameForAllAttributes[product.productType.id]
    config = [
      { type: 'base', group: 'white' }
      { type: 'references', group: 'white' }
      { type: 'attributes', group: 'white' }
      { type: 'variants', group: 'white' }
      { type: 'metaTitle', group: 'white' }
      { type: 'metaDescription', group: 'white' }
      { type: 'metaKeywords', group: 'white' }
      { type: 'categories', group: 'white' }
    ]
    if header.has(CONS.HEADER_PRICES)
      config.push { type: 'prices', group: 'white' }
    else
      config.push { type: 'prices', group: 'black' }
    if header.has(CONS.HEADER_IMAGES)
      config.push { type: 'images', group: 'white' }
    else
      config.push { type: 'images', group: 'black' }

    filtered = @sync.config(config)
    .buildActions(product, existingProduct, allSameValueAttributes)
    .filterActions (action) =>
      # console.log "ACTION", action
      switch action.action
        when 'setAttribute', 'setAttributeInAllVariants'
          (header.has(action.name) or header.hasLanguageForCustomAttribute(action.name)) and not
          @_isBlackListedForUpdate(action.name)
        when 'changeName' then header.has(CONS.HEADER_NAME) or header.hasLanguageForBaseAttribute(CONS.HEADER_NAME)
        when 'changeSlug' then header.has(CONS.HEADER_SLUG) or header.hasLanguageForBaseAttribute(CONS.HEADER_SLUG)
        when 'setDescription' then header.has(CONS.HEADER_DESCRIPTION) or header.hasLanguageForBaseAttribute(CONS.HEADER_DESCRIPTION)
        when 'setMetaTitle' then header.has(CONS.HEADER_META_TITLE) or header.hasLanguageForBaseAttribute(CONS.HEADER_META_TITLE)
        when 'setMetaDescription' then header.has(CONS.HEADER_META_DESCRIPTION) or header.hasLanguageForBaseAttribute(CONS.HEADER_META_DESCRIPTION)
        when 'setMetaKeywords' then header.has(CONS.HEADER_META_KEYWORDS) or header.hasLanguageForBaseAttribute(CONS.HEADER_META_KEYWORDS)
        when 'addToCategory', 'removeFromCategory' then header.has(CONS.HEADER_CATEGORIES)
        when 'setTaxCategory' then header.has(CONS.HEADER_TAX)
        when 'setSKU' then header.has(CONS.HEADER_SKU)
        when 'addVariant', 'addPrice', 'removePrice', 'changePrice', 'addExternalImage', 'removeImage' then true
        when 'removeVariant' then @allowRemovalOfVariants
        else throw Error "The action '#{action.action}' is not supported. Please contact the SPHERE.IO team!"

    if @dryRun
      if filtered.shouldUpdate()
        Promise.resolve "[row #{rowIndex}] DRY-RUN - updates for #{existingProduct.id}:\n#{_.prettify filtered.getUpdatePayload()}"
      else
        Promise.resolve "[row #{rowIndex}] DRY-RUN - nothing to update."
    else
      if filtered.shouldUpdate()
        @client.products.byId(filtered.getUpdateId()).update(filtered.getUpdatePayload())
        .then (result) =>
          @publishProduct(result.body, rowIndex)
          .then -> Promise.resolve "[row #{rowIndex}] Product updated."
        .catch (err) =>
          msg = "[row #{rowIndex}] Problem on updating product:\n#{_.prettify err}\n#{_.prettify err.body}"
          if @continueOnProblems
            Promise.resolve "#{msg} - ignored!"
          else
            Promise.reject msg
      else
        Promise.resolve "[row #{rowIndex}] Product update not necessary."


  create: (product, rowIndex) ->
    if @dryRun
      Promise.resolve "[row #{rowIndex}] DRY-RUN - create new product."
    else if @updatesOnly
      Promise.resolve "[row #{rowIndex}] UPDATES ONLY - nothing done."
    else
      @client.products.create(product)
      .then (result) =>
        @publishProduct(result.body, rowIndex)
        .then -> Promise.resolve "[row #{rowIndex}] New product created."
      .catch (err) =>
        msg = "[row #{rowIndex}] Problem on creating new product:\n#{_.prettify err}\n#{_.prettify err.body}"
        if @continueOnProblems
          Promise.resolve "#{msg} - ignored!"
        else
          Promise.reject msg

  publishProduct: (product, rowIndex, publish = true) ->
    action = if publish then 'publish' else 'unpublish'
    if not @publishProducts
      Promise.resolve "Do not #{action}."
    else if publish and product.published and not product.hasStagedChanges
      Promise.resolve "[row #{rowIndex}] Product is already published - no staged changes."
    else
      data =
        id: product.id
        version: product.version
        actions: [
          action: action
        ]
      @client.products.byId(product.id).update(data)
      .then (result) ->
        Promise.resolve "[row #{rowIndex}] Product #{action}ed."
      .catch (err) =>
        if @continueOnProblems
          Promise.resolve "[row #{rowIndex}] Product is already #{action}ed."
        else
          Promise.reject "[row #{rowIndex}] Problem on #{action}ing product:\n#{_.prettify err}\n#{_.prettify err.body}"

  deleteProduct: (product, rowIndex) ->
    @client.products.byId(product.id).delete(product.version)
    .then ->
      Promise.resolve "[row #{rowIndex}] Product deleted."
    .catch (err) ->
      Promise.reject "[row #{rowIndex}] Error on deleting product:\n#{_.prettify err}\n#{_.prettify err.body}"

module.exports = Import
