_ = require 'underscore'
fs = require 'fs'
Csv = require 'csv'
Types = require '../lib/types'
Categories = require '../lib/categories'
Channels = require '../lib/channels'
CustomerGroups = require '../lib/customergroups'
Header = require '../lib/header'
Taxes = require '../lib/taxes'
ExportMapping = require '../lib/exportmapping'
Q = require 'q'
prompt = require 'prompt'
SphereClient = require 'sphere-node-client'

class Export

  constructor: (options = {}) ->
    @queryString = options.queryString
    @typesService = new Types()
    @categoryService = new Categories()
    @channelService = new Channels()
    @customerGroupService = new CustomerGroups()
    @taxService = new Taxes()
    @client = new SphereClient options

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
    deferred = Q.defer()
    @_parse(templateContent).then (header) =>
      errors = header.validate()
      unless _.size(errors) is 0
        deferred.reject errors
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
          @client.productProjections.staged(staged).all().fetch()
        ]
        Q.all(data)
        .then ([productTypes, categories, channels, customerGroups, taxes, products]) =>
          console.log "Number of product types: #{productTypes.body.total}."
          if products.body.total is 0
            deferred.resolve 'No products found.'
          else
            console.log "Number of products: #{products.body.total}."
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
            @_saveCSV(outputFile, csv).then ->
              deferred.resolve 'Export done.'
    .fail (err) ->
      deferred.reject err
    .done()

    deferred.promise

  exportAsJson: (outputFile) ->
    deferred = Q.defer()
    @client.products.all().fetch()
    .then (result) =>
      products = result.body.results
      if _.size(products) is 0
        deferred.resolve 'No products found.'
      else
        console.log "Number of products: #{_.size products}."
        @_saveJSON(outputFile, products)
        .then ->
          deferred.resolve 'Export done.'
    .fail (err) ->
      deferred.reject err
    .done()

    deferred.promise

  createTemplate: (languages, outputFile, allProductTypes = false) ->
    deferred = Q.defer()
    @typesService.getAll(@client)
    .then (result) =>
      productTypes = result.body.results
      if _.size(productTypes) is 0
        deferred.reject 'Can not find any product type.'
      else
        idsAndNames = _.map productTypes, (productType) ->
          productType.name

        if allProductTypes
          allHeaders = []
          _.each productTypes, (productType) ->
            allHeaders = allHeaders.concat new ExportMapping().createTemplate(productType, languages)
          csv = _.uniq allHeaders
          @_saveCSV(outputFile, [csv]).then ->
            deferred.resolve 'Template for all product types generated.'
        else
          _.each idsAndNames, (entry, index) ->
            console.log '  %d) %s', index, entry
          prompt.start()
          property =
            name: 'number'
            message: 'Enter the number of the producttype.'
            validator: /\d+/
            warning: 'Please enter a valid number'
          prompt.get property, (err, result) =>
            productType = productTypes[parseInt(result.number)]
            if productType
              console.log "Generating template for product type '#{productType.name}' (id: #{productType.id})."
              process.stdin.destroy()
              csv = new ExportMapping().createTemplate(productType, languages)
              @_saveCSV(outputFile, [csv])
              .then ->
                deferred.resolve 'Template generated.'
            else
              deferred.reject 'Please re-run and select a valid number.'
    .fail (err) ->
      deferred.reject err
    .done()

    deferred.promise

  _saveCSV: (file, content) ->
    deferred = Q.defer()
    Csv().from(content).to.path(file, encoding: 'utf8')
    .on 'error', (err) ->
      deferred.reject err
    .on 'close', (count) ->
      deferred.resolve count
    deferred.promise

  _saveJSON: (file, content) ->
    deferred = Q.defer()
    fs.writeFile file, JSON.stringify(content, null, 2), {encoding: 'utf8'}, (err) ->
      deferred.reject err if err
      deferred.resolve true
    deferred.promise

  _parse: (csvString) ->
    deferred = Q.defer()
    Csv().from.string(csvString)
    .to.array (data, count) ->
      header = new Header(data[0])
      deferred.resolve header
    deferred.promise


module.exports = Export
