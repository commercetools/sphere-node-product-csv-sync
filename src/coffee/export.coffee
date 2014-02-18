_ = require 'underscore'
Csv = require 'csv'
CONS = require '../lib/constants'
Types = require '../lib/types'
Header = require '../lib/header'
Products = require '../lib/products'
ExportMapping = require '../lib/exportmapping'
Rest = require('sphere-node-connect').Rest
CommonUpdater = require('sphere-node-sync').CommonUpdater
Q = require 'q'

class Export extends CommonUpdater

  constructor: (options = {}) ->
    super(options)
    @staged = true # TODO
    @queryString = '' # TODO
    @typesService = new Types()
    @productService = new Products()
    @rest = new Rest options if options.config

  _initMapping: (typesService, header) ->
    options =
      typesService: typesService
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
      exportMapping = @_initMapping(@typesService, header)
      @typesService.getAll(@rest).then (productTypes) =>
        console.log "Number of product types: #{_.size productTypes}."
        @typesService.buildMaps productTypes
        for productType in productTypes
          header._productTypeLanguageIndexes(productType)
        @productService.getAllExistingProducts(@rest, @staged, @queryString).then (products) =>
          console.log "Number of products: #{_.size products}."
          if _.size(products) is 0
            @returnResult true, 'No products found.', callback
            return
          csv = [ header.rawHeader ]
          for product in products
            csv = csv.concat(exportMapping.mapProduct(product, productTypes))
          Csv().from(csv).to.path(outputFile, encoding: 'utf8').on 'close', (count) =>
            @returnResult true, 'Export done.', callback
        .fail (msg) =>
          @returnResult false, msg, callback
      .fail (msg) =>
        @returnResult false, msg, callback
    .fail (msg) =>
      @returnResult false, msg, callback

  _parse: (csvString) ->
    deferred = Q.defer()
    Csv().from.string(csvString)
    .to.array (data, count) ->
      header = new Header(data[0])
      deferred.resolve header
    deferred.promise


module.exports = Export