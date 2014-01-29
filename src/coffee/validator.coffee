_ = require('underscore')._
Csv = require 'csv'
CONS = require '../lib/constants'
Types = require '../lib/types'
CustomerGroups = require '../lib/customergroups'
Mapping = require '../lib/mapping'
Header = require '../lib/header'
Rest = require('sphere-node-connect').Rest
Q = require 'q'

class Validator
  constructor: (options = {}) ->
    @types = new Types()
    @customerGroups = new CustomerGroups()
    options.types = @types
    options.customerGroups = @customerGroups
    options.validator = @
    @map = new Mapping options
    @rest = new Rest options if options.config
    @rawProducts = []
    @errors = []

  parse: (csvString, callback) ->
    Csv().from.string(csvString)
    .to.array (data, count) =>
      @header = new Header(data[0])
      @map.header = @header
      callback _.rest(data), count

  validate: (csvContent) ->
    @validateOffline csvContent
    @validateOnline()

  validateOffline: (csvContent) ->
    @header.validate()
    @buildProducts csvContent

  validateOnline: ->
    deferred = Q.defer()
    Q.all([@types.getAllProductTypes(@rest), @customerGroups.getAllCustomerGroups(@rest)]).then ([productTypes, customerGroups]) =>
      @productTypes = productTypes
      @types.buildMaps productTypes
      @customerGroups.buildMaps customerGroups
      @valProducts @rawProducts

      if _.size(@errors) is 0
        deferred.resolve @rawProducts
      else
        deferred.reject @errors
    .fail (msg) ->
      deferred.reject msg

    deferred.promise

  buildProducts: (content) ->
    _.each content, (row, index) =>
      rowIndex = index + 1
      if @isProduct row
        product =
          master: row
          startRow: rowIndex + 1
          variants: []
        @rawProducts.push product
      else if @isVariant row
        product = _.last @rawProducts
        unless product
          @errors.push "[row #{rowIndex}] We need a product before starting with a variant!"
          return
        product.variants.push row
      else
        @errors.push "[row #{rowIndex}] Could not be identified as product or variant!"

  valProducts: (products) ->
    _.each products, (product) =>
      @valProduct product

  valProduct: (raw) ->
    rawMaster = raw.master
    ptInfo = rawMaster[@header.toIndex CONS.HEADER_PRODUCT_TYPE]

    @errors.push "[row #{raw.startRow}] The product type name '#{ptInfo}' is not unique. Please use the ID!" if _.contains(@types.duplicateNames, ptInfo)

    if _.has(@types.name2id, ptInfo)
      ptInfo = @types.name2id[ptInfo]
    if _.has(@types.id2index, ptInfo)
      index = @types.id2index[ptInfo]
      rawMaster[@header.toIndex CONS.HEADER_PRODUCT_TYPE] = @productTypes[index]
    else
      @errors.push "[row #{raw.startRow}] Can't find product type for '#{ptInfo}"

  isVariant: (row) ->
    row[@header.toIndex CONS.HEADER_PRODUCT_TYPE ] is '' and
    row[@header.toIndex CONS.HEADER_NAME ] is '' and
    row[@header.toIndex CONS.HEADER_VARIANT_ID ] isnt undefined # TODO: Check for numbers > 1

  isProduct: (row) ->
    not @isVariant row

module.exports = Validator