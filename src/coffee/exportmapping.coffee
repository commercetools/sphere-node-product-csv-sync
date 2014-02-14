_ = require('underscore')._
_s = require 'underscore.string'
CONS = require '../lib/constants'

class ExportMapping

  mapProduct: (product, productTypes) ->
    productType = productTypes[@types.id2index[product.productType.id]]

    rows = []
    rows.push @mapBaseProduct product, productType

    if product.variants
      for variant in product.variants
        rows.push @mapVariant variant, productType

    rows

  mapBaseProduct: (product, productType) ->
    row = @mapVariant product.masterVariant, productType

    if @header.has(CONS.HEADER_ID)
      row[@header.toIndex CONS.HEADER_ID] = product.id

    if @header.has(CONS.HEADER_PRODUCT_TYPE)
      row[@header.toIndex CONS.HEADER_PRODUCT_TYPE] = productType.name

    if @header.has(CONS.HEADER_TAX) and _.has(product, 'taxCategory')
      row[@header.toIndex CONS.HEADER_TAX] = product.taxCategory.id

    # TODO
    # - categories

    for attribName, h2i of @header.toLanguageIndex()
      for lang, index of h2i
        row[index] = product[attribName][lang]

    row

  mapVariant: (variant, productType) ->
    row = []
    if @header.has(CONS.HEADER_VARIANT_ID)
      row[@header.toIndex CONS.HEADER_VARIANT_ID] = variant.id

    if @header.has(CONS.HEADER_SKU)
      row[@header.toIndex CONS.HEADER_SKU] = variant.sku

    if @header.has(CONS.HEADER_PRICES)
      row[@header.toIndex CONS.HEADER_PRICES] = @mapPrices(variant.prices)

    if @header.has(CONS.HEADER_IMAGES)
      row[@header.toIndex CONS.HEADER_IMAGES] = @mapImages(variant.images)

    if variant.attributes
      for attribute in variant.attributes
        attributeTypeDef = @types.id2nameAttributeDefMap[productType.id][attribute.name].type
        if attributeTypeDef.name is CONS.ATTRIBUTE_TYPE_LTEXT
          @mapLocalizedAttribute attribute, productType
        else if @header.has attribute.name
          row[@header.toIndex attribute.name] = @mapAttribute(attribute, attributeTypeDef)

    row

  mapPrices: (prices) ->
    _.reduce(prices, (acc, price, index) ->
      acc += CONS.DELIM_MULTI_VALUE unless index is 0
      acc + "#{price.value.currencyCode} #{price.value.centAmount}"
    , '')

  mapImages: (images) ->
    _.reduce(images, (acc, image, index) ->
      acc += CONS.DELIM_MULTI_VALUE unless index is 0
      acc + image.url
    , '')

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