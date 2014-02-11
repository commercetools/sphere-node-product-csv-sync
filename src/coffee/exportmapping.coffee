_ = require('underscore')._
_s = require 'underscore.string'
CONS = require '../lib/constants'

class ExportMapping

  mapProduct: (product, productTypes) ->
    productType = productTypes[@types.id2index[product.productType.id]]

    name2attributeDef = {}
    for attribute in productType.attributes
      name2attributeDef[attribute.name] = attribute

    masterRow = @mapVariant product.masterVariant, productType
    masterRow = mapBaseProduct masterRow, product, productType

    rows = []
    rows.push masterRow

    if product.variants
      for variant in product.variants
        rows.push @mapVariant variant, productType
    rows

  mapBaseProduct: (masterRow, product, productType) ->
    if @header.has(CONS.HEADER_ID)
      masterRow[@header.toIndex CONS.HEADER_ID] = product.id

    if @header.has(CONS.HEADER_PRODUCT_TYPE)
      masterRow[@header.toIndex CONS.HEADER_PRODUCT_TYPE] = productType.id
      # TODO: Use name of product type if unique

    # TODO
    # - tax
    # - categories
    # - ...

    for attribName, h2i of @header.toLanguageIndex()
      for lang, index of h2i
        masterRow[index] = product[attribName][lang]

    masterRow


  mapVariant: (variant, productType) ->
    row = []

    if @header.has(CONS.HEADER_VARIANT_ID)
      row[@header.toIndex CONS.HEADER_VARIANT_ID] = variant.id

    if @header.has(CONS.HEADER_SKU)
      row[@header.toIndex CONS.HEADER_SKU] = variant.sku

    if variant.attributes
      for attribute in variant.attributes
        if @header.has attribute.name
          row[@header.toIndex attribute.name] = @mapAttribute(attribute, productType)
        else # ltext attributes
          h2i = @header.productTypeAttributeToIndex productType, attribute.name
          if h2i
            for lang, index of h2i
              row[index] = attribute.value[lang]
    row

  isEnum: (value) ->
    _.has(value, 'key') and _.has(value, 'label')

  mapAttribute: (attribute, productType) ->
    if @isEnum(attribute.value)
      attribute.value.key
    else
      if _.isArray attribute.value
        if @isEnum(attribute.value[0])
          _.reduce(attribute.value, (acc, val, index) ->
            acc += CONS.DELIM_MULTI_VALUE unless index is 0
            acc + val.key
          , '')
        else
          attribute.value.join CONS.DELIM_MULTI_VALUE
      else
        attribute.value


module.exports = ExportMapping