Q = require 'q'
_ = require 'underscore'
CONS = require '../lib/constants'
GLOBALS = require '../lib/globals'
Validator = require '../lib/validator'
{ProductSync} = require 'sphere-node-sync'

class Import

  # TODO:
  # - better organize subcommands / classes / helpers
  # - don't save partial results globally, instead pass them around to functions that need them

  constructor: (options = {}) ->
    if options.config #for easier unit testing
      @sync = new ProductSync options
      @client = @sync._client # share client instance to have only one TaskQueue
      @client.setMaxParallel 10

    @validator = new Validator options
    @publishProducts = false
    @continueOnProblems = false
    @allowRemovalOfVariants = false
    @syncSeoAttributes = true
    @updatesOnly = false
    @dryRun = false
    @blackListedCustomAttributesForUpdate = []

    @customAttributeNameToMatch = undefined

  # current workflow:
  # - parse csv
  # - validate csv
  # - map all parsed products
  # - get all existing products
  # - create/update products based on matches
  #
  # ideally workflow:
  # - stream csv -> chunk
  # - validate chunk
  # - map products in chunk
  # - lookup mapped products in sphere
  # - create/update products based on matches from result
  # - next chunk
  import: (fileContent) ->
    @validator.parse fileContent
    .then (parsed) =>
      console.log "CSV file with #{parsed.count} row(s) loaded."
      @validator.validate(parsed.data)
      .then (rawProducts) =>
        if _.size(@validator.errors) isnt 0
          Q.reject @validator.errors
        else
          # TODO:
          # - process products in batches!!
          # - for each chunk match products -> createOrUpdate
          # - provide a way to accumulate partial results, or just log them to console
          products = []
          console.log "Mapping #{_.size rawProducts} product(s) ..."
          for rawProduct in rawProducts
            products.push @validator.map.mapProduct(rawProduct)
          if _.size(@validator.map.errors) isnt 0
            Q.reject @validator.map.errors
          else
            console.log "Mapping done. Fetching existing product(s) ..."
            @client.productProjections.staged().all().fetch()
            .then (result) =>
              existingProducts = result.body.results
              console.log "Comparing against #{_.size existingProducts} existing product(s) ..."
              @initMatcher existingProducts
              @createOrUpdate(products, @validator.types)

  changeState: (publish = true, remove = false, filterFunction) ->
    @publishProducts = true
    @client.productProjections.staged(remove or publish).all().fetch()
    .then (result) =>
      existingProducts = result.body.results

      console.log "Found #{_.size existingProducts} product(s) ..."
      filteredProducts = _.filter existingProducts, filterFunction
      console.log "Filtered #{_.size filteredProducts} product(s)."

      if _.size(filteredProducts) is 0
        Q 'Nothing to do.'
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

  initMatcher: (existingProducts) ->
    @existingProducts = existingProducts
    @id2index = {}
    @customAttributeValue2index = {}
    @sku2index = {}
    @slug2index = {}
    for product, index in existingProducts
      @id2index[product.id] = index
      if product.slug?
        slug = product.slug[GLOBALS.DEFAULT_LANGUAGE]
        @slug2index[slug] = index if slug?

      product.variants or= []
      variants = [product.masterVariant].concat(product.variants)

      _.each variants, (variant) =>
        sku = @getSku variant
        @sku2index[sku] = index if sku?
        @customAttributeValue2index[@getCustomAttributeValue variant] = index if @customAttributeNameToMatch?

    #console.log "id2index", @id2index
    #console.log "customAttributeValue2index", @customAttributeValue2index
    #console.log "sku2index", @sku2index
    #console.log "slug2index", @slug2index

  getSku: (variant) ->
    variant.sku

  getCustomAttributeValue: (variant) ->
    variant.attributes or= []
    attrib = _.find variant.attributes, (attribute) =>
      attribute.name is @customAttributeNameToMatch
    attrib?.value

  match: (entry) ->
    product = entry.product
    index = @id2index[product.id] if product.id?
    if not index
      index = @_matchOnCustomAttribute product
      if not index
        index = @sku2index[product.masterVariant.sku] if product.masterVariant.sku?
        if not index and (entry.header.has(CONS.HEADER_SLUG) or entry.header.hasLanguageForBaseAttribute(CONS.HEADER_SLUG))
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

  createOrUpdate: (products, types) =>
    if _.size(products) is 0
      Q 'Nothing to do.'
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
        when 'setAttribute', 'setAttributeInAllVariants'
          (header.has(action.name) or header.hasLanguageForCustomAttribute(action.name)) and not
          @_isBlackListedForUpdate(action.name)
        when 'changeName' then header.has(CONS.HEADER_NAME) or header.hasLanguageForBaseAttribute(CONS.HEADER_NAME)
        when 'changeSlug' then header.has(CONS.HEADER_SLUG) or header.hasLanguageForBaseAttribute(CONS.HEADER_SLUG)
        when 'setDescription' then header.has(CONS.HEADER_DESCRIPTION) or header.hasLanguageForBaseAttribute(CONS.HEADER_DESCRIPTION)
        when 'setMetaAttributes'
          (header.has(CONS.HEADER_META_TITLE) or header.hasLanguageForCustomAttribute(CONS.HEADER_META_TITLE)) and
          (header.has(CONS.HEADER_META_DESCRIPTION)  or header.hasLanguageForCustomAttribute(CONS.HEADER_META_DESCRIPTION)) and
          (header.has(CONS.HEADER_META_KEYWORDS) or header.hasLanguageForCustomAttribute(CONS.HEADER_META_KEYWORDS)) and
          @syncSeoAttributes
        when 'addToCategory', 'removeFromCategory' then header.has(CONS.HEADER_CATEGORIES)
        when 'setTaxCategory' then header.has(CONS.HEADER_TAX)
        when 'setSKU' then header.has(CONS.HEADER_SKU)
        when 'addVariant', 'addPrice', 'removePrice', 'changePrice', 'addExternalImage', 'removeImage' then true
        when 'removeVariant' then @allowRemovalOfVariants
        else throw Error "The action '#{action.action}' is not supported. Please contact the SPHERE.IO team!"

    if @dryRun
      updates = filtered.get()
      if updates?
        Q "[row #{rowIndex}] DRY-RUN - updates for #{existingProduct.id}:\n#{_.prettify filtered.get()}"
      else
        Q "[row #{rowIndex}] DRY-RUN - nothing to update."
    else
      filtered.update()
      .then (result) =>
        if result.statusCode is 304
          Q "[row #{rowIndex}] Product update not necessary."
        else
          @publishProduct(result.body, rowIndex).then ->
            Q "[row #{rowIndex}] Product updated."
      .fail (err) =>
        if err.statusCode is 400
          msg = "[row #{rowIndex}] Problem on updating product:\n#{_.prettify err}"
          if @continueOnProblems
            Q "#{msg} - ignored!"
          else
            Q.reject msg
        else
          Q.reject "[row #{rowIndex}] Error on updating product:\n#{_.prettify err}"

  create: (product, rowIndex) ->
    if @dryRun
      Q "[row #{rowIndex}] DRY-RUN - create new product."
    else if @updatesOnly
      Q "[row #{rowIndex}] UPDATES ONLY - nothing done."
    else
      @client.products.create(product)
      .then (result) =>
        @publishProduct(result.body, rowIndex).then ->
          Q "[row #{rowIndex}] New product created."
      .fail (err) =>
        if err.statusCode is 400
          msg = "[row #{rowIndex}] Problem on creating new product:\n#{_.prettify err}"
          if @continueOnProblems
            Q "#{msg} - ignored!"
          else
            Q.reject msg
        else
          Q.reject "[row #{rowIndex}] Error on creating new product:\n#{_.prettify err}"

  publishProduct: (product, rowIndex, publish = true) ->
    action = if publish then 'publish' else 'unpublish'
    if not @publishProducts
      Q "Do not #{action}."
    else if publish and product.published and not product.hasStagedChanges
      Q "[row #{rowIndex}] Product is already published - no staged changes."
    else
      data =
        id: product.id
        version: product.version
        actions: [
          action: action
        ]
      @client.products.byId(product.id).update(data)
      .then (result) ->
        Q "[row #{rowIndex}] Product #{action}ed."
      .fail (err) =>
        if err.statusCode is 400
          if @continueOnProblems
            Q "[row #{rowIndex}] Product is already #{action}ed."
          else
            Q.reject "[row #{rowIndex}] Problem on #{action}ing product:\n#{_.prettify err}"
        else
          Q.reject "[row #{rowIndex}] Error on #{action}ing product:\n#{_.prettify err}"

  deleteProduct: (product, rowIndex) ->
    @client.products.byId(product.id).delete(product.version)
    .then ->
      Q "[row #{rowIndex}] Product deleted."
    .fail (err) ->
      Q.reject "[row #{rowIndex}] Error on deleting product:\n#{_.prettify err}"

module.exports = Import
