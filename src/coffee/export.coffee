_ = require 'underscore'
fs = require 'fs'
Csv = require 'csv'
Types = require '../lib/types'
Categories = require '../lib/categories'
Channels = require '../lib/channels'
CustomerGroups = require '../lib/customergroups'
Header = require '../lib/header'
Products = require '../lib/products'
Taxes = require '../lib/taxes'
ExportMapping = require '../lib/exportmapping'
Q = require 'q'
prompt = require 'prompt'

class Export

  constructor: (options = {}) ->
    super(options)
    @queryString = options.queryString
    @typesService = new Types()
    @categoryService = new Categories()
    @channelService = new Channels()
    @customerGroupService = new CustomerGroups()
    @productService = new Products()
    @taxService = new Taxes()
    @rest = new Rest options if options.config

  _initMapping: (header) ->
    options =
      channelService: @channelService
      categoryService: @categoryService
      typesService: @typesService
      customerGroupService: @customerGroupService
      taxService: @taxService
      header: header
    new ExportMapping(options)

  export: (templateContent, outputFile, callback) ->
    @_parse(templateContent).then (header) =>
      errors = header.validate()
      unless _.size(errors) is 0
        @returnResult false, errors, callback
        return
      header.toIndex()
      header.toLanguageIndex()
      exportMapping = @_initMapping(header)
      data = [
        @typesService.getAll @rest
        @categoryService.getAll @rest
        @channelService.getAll @rest
        @customerGroupService.getAll @rest
        @taxService.getAll @rest
        @productService.getAllExistingProducts @rest, @queryString
      ]
      Q.all(data).then ([productTypes, categories, channels, customerGroups, taxes, products]) =>
        console.log "Number of product types: #{_.size productTypes}."
        if _.size(products) is 0
          @returnResult true, 'No products found.', callback
          return
        console.log "Number of products: #{_.size products}."
        @typesService.buildMaps productTypes
        @categoryService.buildMaps categories
        @channelService.buildMaps channels
        @customerGroupService.buildMaps customerGroups
        @taxService.buildMaps taxes
        for productType in productTypes
          header._productTypeLanguageIndexes(productType)
        csv = [ header.rawHeader ]
        for product in products
          csv = csv.concat exportMapping.mapProduct(product, productTypes)
        @_saveCSV(outputFile, csv).then =>
          @returnResult true, 'Export done.', callback
    .fail (msg) =>
      @returnResult false, msg, callback

  exportAsJson: (outputFile, callback) ->
    @productService.getAllExistingProducts @rest, @queryString
    .then (products) =>
      if _.size(products) is 0
        @returnResult true, 'No products found.', callback
        return
      console.log "Number of products: #{_.size products}."
      @_saveJSON(outputFile, products).then =>
        @returnResult true, 'Export done.', callback
    .fail (msg) =>
      @returnResult false, msg, callback

  createTemplate: (languages, outputFile, allProductTypes = false, callback) ->
    @typesService.getAll(@rest).then (productTypes) =>
      if _.size(productTypes) is 0
        @returnResult false, 'Can not find any product type.', callback
        return
      idsAndNames = _.map productTypes, (productType) ->
        productType.name

      if allProductTypes
        allHeaders = []
        _.each productTypes, (productType) ->
          allHeaders = allHeaders.concat new ExportMapping().createTemplate(productType, languages)
        csv = _.uniq allHeaders
        @_saveCSV(outputFile, [csv]).then =>
          @returnResult true, 'Template for all product types generated.', callback
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
            @_saveCSV(outputFile, [csv]).then =>
              @returnResult true, 'Template generated.', callback
          else
            @returnResult false, "Please re-run and select a valid number.", callback
    .fail (msg) =>
      @returnResult false, msg, callback

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
