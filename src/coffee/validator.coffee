_ = require('underscore')._
_s = require 'underscore.string'
Csv = require 'csv'
CONS = require '../lib/constants'
GLOBALS = require '../lib/globals'
Types = require '../lib/types'
Categories = require '../lib/categories'
CustomerGroups = require '../lib/customergroups'
Taxes = require '../lib/taxes'
Channels = require '../lib/channels'
Mapping = require '../lib/mapping'
Header = require '../lib/header'
Q = require 'q'
SphereClient = require 'sphere-node-client'

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
    @client = new SphereClient options if options.config
    @rawProducts = []
    @errors = []
    @suppressMissingHeaderWarning = false
    @csvOptions =
      delimiter: options.csvDelimiter or ','
      quote: options.csvQuote or '"'

  parse: (csvString, callback) ->
    Csv().from.string(csvString, @csvOptions)
    .to.array (data, count) =>
      @header = new Header(data[0])
      @map.header = @header
      callback _.rest(data), count

  validate: (csvContent) ->
    @validateOffline csvContent
    @validateOnline()

  validateOffline: (csvContent) ->
    @header.validate()
    @checkDelimiters()

    variantHeader = CONS.HEADER_VARIANT_ID if @header.has(CONS.HEADER_VARIANT_ID)
    @buildProducts csvContent, variantHeader

  checkDelimiters: ->
    allDelimiter = {
      csvDelimiter: @csvOptions.delimiter,
      csvQuote: @csvOptions.quote,
      language: GLOBALS.DELIM_HEADER_LANGUAGE,
      multiValue: GLOBALS.DELIM_MULTI_VALUE,
      categoryChildren: GLOBALS.DELIM_CATEGORY_CHILD
    }
    delims = _.map allDelimiter, (delim, _) -> delim
    if _.size(delims) isnt _.size(_.uniq(delims))
      @errors.push "Your selected delimiter clash with each other: #{JSON.stringify(allDelimiter)}"

  validateOnline: ->
    gets = [
      @types.getAll @client
      @customerGroups.getAll @client
      @categories.getAll @client
      @taxes.getAll @client
      @channels.getAll @client
    ]
    Q.all(gets)
    .then ([productTypes, customerGroups, categories, taxes, channels]) =>
      @productTypes = productTypes.body.results
      @types.buildMaps productTypes.body.results
      @customerGroups.buildMaps customerGroups.body.results
      @categories.buildMaps categories.body.results
      @taxes.buildMaps taxes.body.results
      @channels.buildMaps channels.body.results

      @valProducts @rawProducts
      if _.size(@errors) is 0
        @valProductTypes @productTypes
        if _.size(@errors) is 0
          Q @rawProducts
        else
          Q.reject @errors
      else
        Q.reject @errors


  # TODO: Allow to define a column that defines the variant relationship.
  # If the value is the same, they belong to the same product
  buildProducts: (content, variantColumn) ->
    _.each content, (row, index) =>
      rowIndex = index + 2 # Excel et all start counting at 1 and we already popped the header
      if @isProduct row, variantColumn
        product =
          master: row
          startRow: rowIndex
          variants: []
        @rawProducts.push product
      else if @isVariant row, variantColumn
        product = _.last @rawProducts
        unless product
          @errors.push "[row #{rowIndex}] We need a product before starting with a variant!"
          return
        product.variants.push row
      else
        @errors.push "[row #{rowIndex}] Could not be identified as product or variant!"

  valProductTypes: (productTypes) ->
    return if @suppressMissingHeaderWarning
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
      @errors.push "[row #{raw.startRow}] Can't find product type for '#{ptInfo}'"

  isVariant: (row, variantColumn) ->
    if variantColumn is CONS.HEADER_VARIANT_ID
      variantId = row[@header.toIndex(CONS.HEADER_VARIANT_ID)]
      parseInt(variantId) > 1
    else
      not @isProduct row

  isProduct: (row, variantColumn) ->
    hasProductTypeColumn = not _s.isBlank(row[@header.toIndex(CONS.HEADER_PRODUCT_TYPE)])
    if variantColumn is CONS.HEADER_VARIANT_ID
      hasProductTypeColumn and row[@header.toIndex(CONS.HEADER_VARIANT_ID)] is '1'
    else
      hasProductTypeColumn

  _hasVariantCriteria: (row, variantColumn) ->
    critertia = row[@header.toIndex(variantColumn)]
    critertia?

module.exports = Validator
