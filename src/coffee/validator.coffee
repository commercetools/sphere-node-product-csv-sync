_ = require('underscore')._
Csv = require 'csv'
CONS = require '../lib/constants'
Types = require '../lib/types'
Mapping = require '../lib/mapping'
Rest = require('sphere-node-connect').Rest
Q = require 'q'

class Validator
  constructor: (options = {}) ->
    @types = new Types()
    options.types = @types
    options.validator = @
    @map = new Mapping options
    @rest = new Rest options if options.config
    @rawProducts = []
    @errors = []

  parse: (csvString, callback) ->
    Csv().from.string(csvString)
    .to.array (data, count) ->
      callback data, count

  header2index: (header) ->
    @h2i = @map.header2index header unless @h2i
    @map.h2i = @h2i

  validate: (csvContent) ->
    @validateOffline csvContent
    @validateOnline()

  validateOffline: (csvContent) ->
    @header = csvContent[0]
    @map.header = @header

    content = _.rest csvContent

    @valHeader @header
    @header2index @header

    @buildProducts content

  validateOnline: ->
    deferred = Q.defer()
    @types.getAllProductTypes(@rest).then (productTypes) =>
      @productTypes = productTypes
      @types.buildProductTypeMaps(productTypes)
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

  valProducts: (products) ->
    _.each products, (product) =>
      @valProduct product

  valProduct: (raw) ->
    rawMaster = raw.master
    ptInfo = rawMaster[@h2i[CONS.HEADER_PRODUCT_TYPE]]

    @errors.push "The product type name '#{ptInfo}' is not unique. Please use the ID!" if @types.duplicateNames[ptInfo]

    index = @types.id2index[@types.name2id[ptInfo]]
    #index = @types.id2index[ptInfo] unless index
    #unless index
    #  @errors.push "Can't find product type for '#{ptInfo}'!"
    #  return

    rawMaster[@h2i[CONS.HEADER_PRODUCT_TYPE]] = @productTypes[index]

  valHeader: (header) ->
    if header.length isnt _.unique(header).length
      @errors.push "There are duplicate header entries!"

    remaining = _.difference CONS.BASE_HEADERS, header
    if _.size(remaining) > 0
      for r in remaining
        @errors.push "Can't find necessary base header '#{r}'!"

  isVariant: (row) ->
    row[@h2i[CONS.HEADER_PRODUCT_TYPE]] is '' and
    row[@h2i[CONS.HEADER_NAME]] is '' and
    row[@h2i[CONS.HEADER_VARIANT_ID]] isnt undefined # TODO: Check for numbers > 1

  isProduct: (row) ->
    not @isVariant row

module.exports = Validator