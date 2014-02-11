_ = require('underscore')._
_s = require 'underscore.string'
CONS = require '../lib/constants'

class ExportMapping

  mapProduct: (product, productTypes) ->
    productType = productTypes[@types.id2index[product.productType.id]]

    masterRow = @mapVariant product.masterVariant, productType
    masterRow = @mapBaseProduct masterRow, product, productType

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

    # TODO:
    # - prices
    # - images

    if variant.attributes
      for attribute in variant.attributes
        attributeTypeDef = @types.id2nameAttributeDefMap[productType.id][attribute.name].type
        if attributeTypeDef.name is CONS.ATTRIBUTE_TYPE_LTEXT
          @mapLocalizedAttribute attribute, productType
        else if @header.has attribute.name
          row[@header.toIndex attribute.name] = @mapAttribute(attribute, attributeTypeDef)

    row

  mapAttribute: (attribute, attributeTypeDef) ->
    switch attributeTypeDef.name
      when CONS.ATTRIBUTE_TYPE_SET then @mapSetAttribute(attribute, attributeTypeDef)
      when CONS.ATTRIBUTE_TYPE_ENUM, CONS.ATTRIBUTE_TYPE_LENUM then attribute.value.key
      when CONS.ATTRIBUTE_TYPE_MONEY then #TODO
      else attribute.value

  mapLocalizedAttribute: (attribute, productType) ->
    h2i = @header.productTypeAttributeToIndex productType, attribute.name
    if h2i
      for lang, index of h2i
        attribute.value[lang]

  mapSetAttribute: (attribute, attributeTypeDef) ->
    switch attributeTypeDef.elementType.name
      when CONS.ATTRIBUTE_TYPE_ENUM, CONS.ATTRIBUTE_TYPE_LENUM
        _.reduce(attribute.value, (acc, val, index) ->
          acc += CONS.DELIM_MULTI_VALUE unless index is 0
          acc + val.key
        , '')
      # TODO: check other elementTypes
      else
        attribute.value.join CONS.DELIM_MULTI_VALUE


module.exports = ExportMapping