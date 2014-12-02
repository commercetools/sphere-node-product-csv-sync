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

  constructor: (options = {}) ->
    @queryOptions =
      queryString: options.export?.queryString?.trim()
      queryType: options.export?.queryType
      isQueryEncoded: options.export?.isQueryEncoded
    @client = new SphereClient options.client

    # TODO: using single mapping util instead of services
    @typesService = new Types()
    @categoryService = new Categories()
    @channelService = new Channels()
    @customerGroupService = new CustomerGroups()
    @taxService = new Taxes()

  _initMapping: (header) ->
    options =
      channelService: @channelService
      categoryService: @categoryService
      typesService: @typesService
      customerGroupService: @customerGroupService
      taxService: @taxService
      header: header
    new ExportMapping(options)

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
        productsService = @client.productProjections
        if @queryOptions.queryString
          productsService.byQueryString(@queryOptions.queryString, @queryOptions.isQueryEncoded)
        else
          productsService.all().staged(staged)
        data = [
          @typesService.getAll @client
          @categoryService.getAll @client
          @channelService.getAll @client
          @customerGroupService.getAll @client
          @taxService.getAll @client
          if @queryOptions.queryType is 'search' then productsService.search() else productsService.fetch()
        ]
        # TODO:
        # - use process to export products in batches
        # - use streams to write data chunks
        Promise.all(data)
        .then ([productTypes, categories, channels, customerGroups, taxes, products]) =>
          console.log "Number of product types: #{productTypes.body.total}."
          if products.body.total is 0
            Promise.resolve 'No products found.'
          else
            console.log "Number of fetched products: #{products.body.count}."
            @typesService.buildMaps productTypes.body.results
            @categoryService.buildMaps categories.body.results
            @channelService.buildMaps channels.body.results
            @customerGroupService.buildMaps customerGroups.body.results
            @taxService.buildMaps taxes.body.results
            for productType in productTypes.body.results
              header._productTypeLanguageIndexes(productType)
            csv = [ header.rawHeader ]
            for product in products.body.results
              csv = csv.concat exportMapping.mapProduct(product, productTypes.body.results)

            @_saveCSV(outputFile, csv)
            .then -> Promise.resolve 'Export done.'

  exportAsJson: (outputFile) ->
    # TODO:
    # - use process to export products in batches
    # - use streams to write data chunks
    @client.products.all().fetch()
    .then (result) =>
      products = result.body.results
      if _.size(products) is 0
        Promise.resolve 'No products found.'
      else
        console.log "Number of products: #{_.size products}."
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
            console.log '  %d) %s', index, entry
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
              console.log "Generating template for product type '#{productType.name}' (id: #{productType.id})."
              process.stdin.destroy()
              csv = new ExportMapping().createTemplate(productType, languages)
              @_saveCSV(outputFile, [csv])
              .then -> Promise.resolve 'Template generated.'
            else
              Promise.reject 'Please re-run and select a valid number.'

  _saveCSV: (file, content) ->
    new Promise (resolve, reject) ->
      Csv().from(content)
      .to.path file, {encoding: 'utf8'}
      .on 'error', (err) -> reject err
      .on 'close', (count) -> resolve count

  _saveJSON: (file, content) ->
    fs.writeFileAsync file, JSON.stringify(content, null, 2), {encoding: 'utf8'}

  _parse: (csvString) ->
    new Promise (resolve, reject) ->
      Csv().from.string(csvString)
      .to.array (data, count) ->
        header = new Header(data[0])
        resolve header
      .on 'error', (err) -> reject err

module.exports = Export
