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
    @types = new Types()
    @productService = new Products()
    @exportMapping = new ExportMapping()
    @exportMapping.types = @types
    @rest = new Rest options if options.config

  export: (templateContent, outputFile, callback) ->
    @parse(templateContent).then (header) =>
      errors = header.validate()
      unless _.size(errors) is 0
        @returnResult false, errors, callback
        return
      header.toIndex()
      header.toLanguageIndex()
      @exportMapping.header = header
      @types.getAll(@rest).then (productTypes) =>
        console.log "Number of product types: #{_.size productTypes}."
        @types.buildMaps productTypes
        for productType in productTypes
          header._productTypeLanguageIndexes(productType)
        @productService.getAllExistingProducts(@rest, @staged).then (products) =>
          console.log "Number of products: #{_.size products}."
          if _.size(products) is 0
            @returnResult true, 'No products found.', callback
            return
          csv = [ header.rawHeader ]
          for product in products
            csv = csv.concat(@exportMapping.mapProduct(product, productTypes))
          Csv().from(csv).to.path(outputFile, encoding: 'utf8').on 'close', (count) =>
            @returnResult true, 'Export done.', callback
        .fail (msg) ->
          @returnResult false, msg, callback
      .fail (msg) ->
        @returnResult false, msg, callback
    .fail (msg) ->
      @returnResult false, msg, callback

  parse: (csvString) ->
    deferred = Q.defer()
    Csv().from.string(csvString)
    .to.array (data, count) ->
      header = new Header(data[0])
      deferred.resolve header
    deferred.promise


module.exports = Export