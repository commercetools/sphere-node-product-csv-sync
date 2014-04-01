_ = require('underscore')._
_s = require 'underscore.string'
Csv = require 'csv'
CONS = require '../lib/constants'
Types = require '../lib/types'
Categories = require '../lib/categories'
CustomerGroups = require '../lib/customergroups'
Taxes = require '../lib/taxes'
Channels = require '../lib/channels'
Mapping = require '../lib/mapping'
Header = require '../lib/header'
Rest = require('sphere-node-connect').Rest
Q = require 'q'

class Validator
  constructor: (options = {}) ->
    @types = new Types()
    @customerGroups = new CustomerGroups()
    @categories = new Categories()
    @taxes = new Taxes()
    @channels = new Channels()
    options.types = @types
    options.customerGroups = @customerGroups
    options.categories = @categories
    options.taxes = @taxes
    options.channels = @channels
    options.validator = @
    @map = new Mapping options
    @rest = new Rest options if options.config
    @rawProducts = []
    @errors = []
    @suppressHeaderWarnings = false

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
    gets = [
      @types.getAll @rest
      @customerGroups.getAll @rest
      @categories.getAll @rest
      @taxes.getAll @rest
      @channels.getAll @rest
    ]
    Q.all(gets).then ([productTypes, customerGroups, categories, taxes, channels]) =>
      @productTypes = productTypes
      @types.buildMaps productTypes
      @customerGroups.buildMaps customerGroups
      @categories.buildMaps categories
      @taxes.buildMaps taxes
      @channels.buildMaps channels

      @valProductTypes @productTypes
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
      rowIndex = index + 2 # Excel et all start counting at 1 and we already popped the header
      if @isProduct row
        product =
          master: row
          startRow: rowIndex
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

  valProductTypes: (productTypes) ->
    return if @suppressHeaderWarnings
    _.each productTypes, (pt) =>
      attributes = @header.missingHeaderForProductType pt
      unless _.isEmpty(attributes)
        console.warn "For the product type '#{pt.name}' the following attributes don't have a matching header:"
        _.each attributes, (attr) ->
          console.warn "  #{attr.name}: type '#{attr.type.name} #{if attr.type.name is 'set' then 'of ' + attr.type.elementType.name  else ''}' - constraint '#{attr.attributeConstraint}' - #{if attr.isRequired then 'isRequired' else 'optional'}"

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
    variantId = row[@header.toIndex(CONS.HEADER_VARIANT_ID)]
    parseInt(variantId) > 1

  isProduct: (row) ->
    not _s.isBlank(row[@header.toIndex(CONS.HEADER_PRODUCT_TYPE)]) and
    row[@header.toIndex(CONS.HEADER_VARIANT_ID)] is '1'

module.exports = Validator