_ = require 'underscore'
Csv = require 'csv'
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')
prompt = Promise.promisifyAll require('prompt')
{SphereClient} = require 'sphere-node-sdk'
Types = require './types'
Categories = require './categories'
Channels = require './channels'
CustomerGroups = require './customergroups'
Header = require './header'
Taxes = require './taxes'
ExportMapping = require './exportmapping'

# TODO:
# - JSDoc
class Export

  constructor: (@options = {}) ->
    @queryOptions =
      queryString: @options.export?.queryString?.trim()
      queryType: @options.export?.queryType
      isQueryEncoded: @options.export?.isQueryEncoded
    @client = new SphereClient @options.client

    # TODO: using single mapping util instead of services
    @typesService = new Types()
    @categoryService = new Categories()
    @channelService = new Channels()
    @customerGroupService = new CustomerGroups()
    @taxService = new Taxes()

  _initMapping: (header) ->
    _.extend @options,
      channelService: @channelService
      categoryService: @categoryService
      typesService: @typesService
      customerGroupService: @customerGroupService
      taxService: @taxService
      header: header
    new ExportMapping(@options)

  # return the correct product service in case query string is used or not
  _getProductService: (staged = true) ->
    productsService = @client.productProjections
    if @queryOptions.queryString
      productsService.byQueryString(@queryOptions.queryString, @queryOptions.isQueryEncoded)
      if @queryOptions.queryType is 'search'
        # FIXME: this doesn't work with methods like `process`
        # as the base resource endpoint will be used
        # (in this case `/product-projections`).
        # Should be fixed upstream in the `node-sdk`.
        productsService.asSearch()
      else
        productsService
    else
      productsService.all().perPage(500).staged(staged)

  export: (templateContent, outputFile, staged = true) ->
    @_parse(templateContent)
    .then (header) =>
      errors = header.validate()
      unless _.size(errors) is 0
        Promise.reject errors
      else
        header.toIndex()
        header.toLanguageIndex()
        exportMapping = @_initMapping(header)

        data = [
          @typesService.getAll @client
          @categoryService.getAll @client
          @channelService.getAll @client
          @customerGroupService.getAll @client
          @taxService.getAll @client
        ]
        Promise.all(data)
        .then ([productTypes, categories, channels, customerGroups, taxes]) =>
          @typesService.buildMaps productTypes.body.results
          @categoryService.buildMaps categories.body.results
          @channelService.buildMaps channels.body.results
          @customerGroupService.buildMaps customerGroups.body.results
          @taxService.buildMaps taxes.body.results

          console.warn "Fetched #{productTypes.body.total} product type(s)."
          _.each productTypes.body.results, (productType) ->
            header._productTypeLanguageIndexes(productType)

          processChunk = (products) =>
            current = products.body.offset + products.body.count
            console.warn "Fetched #{products.body.count} product(s)."
            csv = []
            _.each products.body.results, (product) ->
              # filter unwanted variants
              product.variants = _.filter(product.variants, (variant) ->
                return _.isUndefined(variant.isMatchingVariant) ||
                  variant.isMatchingVariant == true
              )
              csv = csv.concat exportMapping.mapProduct(product, productTypes.body.results)
            @_saveCSV(outputFile, csv, true)

          @_saveCSV(outputFile, [ header.rawHeader ] )
          .then (r) =>

            @_getProductService(staged)
            .process(processChunk, {accumulate: false})
            .then (result) ->
              Promise.resolve "Export done."

  exportAsJson: (outputFile) ->
    # TODO:
    # - use process to export products in batches
    # - use streams to write data chunks
    @_getProductService()
    .then (result) =>
      products = result.body.results
      if _.size(products) is 0
        Promise.resolve 'No products found.'
      else
        console.warn "Number of fetched products: #{result.body.count}/#{result.body.total}."
        @_saveJSON(outputFile, products)
        .then -> Promise.resolve 'Export done.'

  createTemplate: (languages, outputFile, allProductTypes = false) ->
    @typesService.getAll(@client)
    .then (result) =>
      productTypes = result.body.results
      if _.size(productTypes) is 0
        Promise.reject 'Can not find any product type.'
      else
        idsAndNames = _.map productTypes, (productType) ->
          productType.name

        if allProductTypes
          allHeaders = []
          exportMapping = new ExportMapping()
          _.each productTypes, (productType) ->
            allHeaders = allHeaders.concat exportMapping.createTemplate(productType, languages)
          csv = _.uniq allHeaders
          @_saveCSV(outputFile, [csv])
          .then -> Promise.resolve 'Template for all product types generated.'
        else
          _.each idsAndNames, (entry, index) ->
            console.warn '  %d) %s', index, entry
          prompt.start()
          property =
            name: 'number'
            message: 'Enter the number of the producttype.'
            validator: /\d+/
            warning: 'Please enter a valid number'
          prompt.getAsync property
          .then (result) =>
            productType = productTypes[parseInt(result.number)]
            if productType
              console.warn "Generating template for product type '#{productType.name}' (id: #{productType.id})."
              process.stdin.destroy()
              csv = new ExportMapping().createTemplate(productType, languages)
              @_saveCSV(outputFile, [csv])
              .then -> Promise.resolve 'Template generated.'
            else
              Promise.reject 'Please re-run and select a valid number.'

  _saveCSV: (file, content, append) ->
    flags = if append then 'a' else 'w'
    new Promise (resolve, reject) ->
      parsedCsv = Csv().from content
      opts =
        encoding: 'utf8'
        flags: flags
        eof: true

      if file then parsedCsv.to.path file, opts
      else parsedCsv.to.stream process.stdout, opts

      parsedCsv
      .on 'error', (err) -> reject err
      .on 'close', (count) -> resolve count

  _saveJSON: (file, content) ->
    content = JSON.stringify content, null, 2
    opts =
      encoding: 'utf8'

    if file then fs.writeFileAsync file, content, opts
    else process.stdout.write content

  _parse: (csvString) ->
    new Promise (resolve, reject) ->
      Csv().from.string(csvString)
      .to.array (data, count) ->
        header = new Header(data[0])
        resolve header
      .on 'error', (err) -> reject err

module.exports = Export
