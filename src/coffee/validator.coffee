_ = require('underscore')._
Csv = require 'csv'
Mapping = require '../lib/mapping'

class Validator
  constructor: (options) ->
    @map = new Mapping()
    @HEADER_PRODUCT_TYPE = 'productType'
    @HEADER_VARIANT_ID = 'variantId'

  parse: (csvString, callback) ->
    Csv().from.string(csvString)
    .to.array (data, count) ->
      callback data, count
    .on "error", (error) ->
      throw new Error error

  header2index: (header) ->
    @h2i = @map.header2index header unless @h2i

  validate: (csvContent) ->
    errors = []
    @header = csvContent[0]
    errors.concat(@valHeader @header)
    @header2index @header

    content = _.rest csvContent
    errors.concat(@buildProducts content)
    errors.concat(@valProducts @products)
    errors

  buildProducts: (content) ->
    errors = []
    @products = []
    _.each content, (row, index) =>
      row_index = index + 1
      if @isProduct row
        product =
          masterVariant: row
          start_row: row_index
          variants: []
        @products.push product
      else if @isVariant row
        product = _.last @products
        unless product
          errors.push "[row #{row_index}] We need a product before starting with a variant!"
          return errors
        product.variants.push row
      else
        errors.push "[row #{row_index}] Could not be identified as product or variant!"
    errors

  valProducts: (products) ->
    errors = []
    _.each products, (product) =>
      errors.concat(@valProduct product)
    errors

  valProduct: (raw) ->
    errors = []
    product = raw.masterVariant
    variants = raw.variants
    errors

  valProductType: () ->
    true

  valProductTypeAttributes: () ->
    true

  valHeader: (csvContent) ->
    errors = []
    # TODO: check for duplicate entries
    necessaryAttributes = [ @HEADER_PRODUCT_TYPE, @HEADER_VARIANT_ID ]
    header = csvContent[0]
    remaining = _.difference necessaryAttributes, header
    if _.size(remaining) > 0
      for r in remaining
        errors.push "Can't find necessary header '#{r}'"
    errors

  isVariant: (row) ->
    row[@h2i[@HEADER_PRODUCT_TYPE]] is '' and row[@h2i[@HEADER_VARIANT_ID]] isnt undefined

  isProduct: (row) ->
    not @isVariant row

module.exports = Validator