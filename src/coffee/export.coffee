_ = require 'underscore'
Csv = require 'csv'
CONS = require '../lib/constants'
Types = require '../lib/types'
Channels = require '../lib/channels'
CustomerGroups = require '../lib/customergroups'
Header = require '../lib/header'
Products = require '../lib/products'
Taxes = require '../lib/taxes'
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
    @channelService = new Channels()
    @customerGroupService = new CustomerGroups()
    @productService = new Products()
    @taxService = new Taxes()
    @rest = new Rest options if options.config

  _initMapping: (header) ->
    options =
      channelService: @channelService
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
        @channelService.getAll @rest
        @customerGroupService.getAll @rest
        @taxService.getAll @rest
        @productService.getAllExistingProducts @rest, @staged, @queryString
      ]
      Q.all(data).then ([productTypes, channels, customerGroups, taxes, products]) =>
        console.log "Number of product types: #{_.size productTypes}."
        if _.size(products) is 0
          @returnResult true, 'No products found.', callback
          return
        console.log "Number of products: #{_.size products}."
        @typesService.buildMaps productTypes
        @channelService.buildMaps channels
        @customerGroupService.buildMaps customerGroups
        @taxService.buildMaps taxes
        for productType in productTypes
          header._productTypeLanguageIndexes(productType)
        csv = [ header.rawHeader ]
        for product in products
          csv = csv.concat exportMapping.mapProduct(product, productTypes)
        Csv().from(csv).to.path(outputFile, encoding: 'utf8').on 'close', (count) =>
          @returnResult true, 'Export done.', callback
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