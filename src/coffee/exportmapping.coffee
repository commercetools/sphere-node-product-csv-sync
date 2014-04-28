_ = require('underscore')._
_s = require 'underscore.string'
CONS = require '../lib/constants'

class ExportMapping

  constructor: (options = {}) ->
    @typesService = options.typesService
    @categoryService = options.categoryService
    @channelService = options.channelService
    @customerGroupService = options.customerGroupService
    @taxService = options.taxService
    @header = options.header

  mapProduct: (product, productTypes) ->
    productType = productTypes[@typesService.id2index[product.productType.id]]

    rows = []
    rows.push @_mapBaseProduct product, productType

    if product.variants
      for variant in product.variants
        rows.push @_mapVariant variant, productType

    rows

  createTemplate: (productType, languages = [CONS.DEFAULT_LANGUAGE]) ->
    header = [ CONS.HEADER_PUBLISHED, CONS.HEADER_HAS_STAGED_CHANGES ].concat(CONS.BASE_HEADERS.concat(CONS.SPECIAL_HEADERS))
    _.each CONS.BASE_LOCALIZED_HEADERS, (locBaseAttrib) ->
      header = header.concat _.map languages, (lang) ->
        "#{locBaseAttrib}#{CONS.DELIM_HEADER_LANGUAGE}#{lang}"
    _.each productType.attributes, (attribute) =>
      switch attribute.type.name
        when CONS.ATTRIBUTE_TYPE_SET then header = header.concat @_mapAttributeTypeDef attribute.type.elementType, attribute, languages
        else header = header.concat @_mapAttributeTypeDef attribute.type, attribute, languages
    header

  _mapAttributeTypeDef: (attributeTypeDef, attribute, languages) ->
    switch attributeTypeDef.name
      when CONS.ATTRIBUTE_TYPE_LTEXT then _.map languages, (lang) -> "#{attribute.name}#{CONS.DELIM_HEADER_LANGUAGE}#{lang}"
      else [ attribute.name ]

  _mapBaseProduct: (product, productType) ->
    row = @_mapVariant product.masterVariant, productType

    if @header.has(CONS.HEADER_PUBLISHED)
      row[@header.toIndex CONS.HEADER_PUBLISHED] = "#{product.published}"

    if @header.has(CONS.HEADER_HAS_STAGED_CHANGES)
      row[@header.toIndex CONS.HEADER_HAS_STAGED_CHANGES] = "#{product.hasStagedChanges}"

    if @header.has(CONS.HEADER_ID)
      row[@header.toIndex CONS.HEADER_ID] = product.id

    if @header.has(CONS.HEADER_PRODUCT_TYPE)
      row[@header.toIndex CONS.HEADER_PRODUCT_TYPE] = productType.name

    if @header.has(CONS.HEADER_TAX) and _.has(product, 'taxCategory')
      if _.has @taxService.id2name, product.taxCategory.id
        row[@header.toIndex CONS.HEADER_TAX] = @taxService.id2name[product.taxCategory.id]

    if @header.has(CONS.HEADER_CATEGORIES)
      row[@header.toIndex CONS.HEADER_CATEGORIES] = _.reduce(product.categories or [], (memo, category, index) =>
        memo += CONS.DELIM_MULTI_VALUE unless index is 0
        memo + @categoryService.id2fqName[category.id]
      , '')

    if @header.has(CONS.HEADER_CREATED_AT)
      row[@header.toIndex CONS.HEADER_CREATED_AT] = product.createdAt

    if @header.has(CONS.HEADER_LAST_MODIFIED_AT)
      row[@header.toIndex CONS.HEADER_LAST_MODIFIED_AT] = product.lastModifiedAt

    for attribName, h2i of @header.toLanguageIndex()
      for lang, index of h2i
        if product[attribName]
          row[index] = product[attribName][lang]

    row

  _mapVariant: (variant, productType) ->
    row = []
    if @header.has(CONS.HEADER_VARIANT_ID)
      row[@header.toIndex CONS.HEADER_VARIANT_ID] = variant.id

    if @header.has(CONS.HEADER_SKU)
      row[@header.toIndex CONS.HEADER_SKU] = variant.sku

    if @header.has(CONS.HEADER_PRICES)
      row[@header.toIndex CONS.HEADER_PRICES] = @_mapPrices(variant.prices)

    if @header.has(CONS.HEADER_IMAGES)
      row[@header.toIndex CONS.HEADER_IMAGES] = @_mapImages(variant.images)

    if variant.attributes
      for attribute in variant.attributes
        attributeTypeDef = @typesService.id2nameAttributeDefMap[productType.id][attribute.name].type
        if attributeTypeDef.name is CONS.ATTRIBUTE_TYPE_LTEXT
          row = @_mapLocalizedAttribute attribute, productType, row
        else if @header.has attribute.name
          row[@header.toIndex attribute.name] = @_mapAttribute(attribute, attributeTypeDef)

    row

  _mapPrices: (prices) ->
    _.reduce(prices, (acc, price, index) =>
      acc += CONS.DELIM_MULTI_VALUE unless index is 0
      countryPart = ''
      if price.country
        countryPart = "#{price.country}-"
      customerGroupPart = ''
      if price.customerGroup and _.has(@customerGroupService.id2name, price.customerGroup.id)
        customerGroupPart = " #{@customerGroupService.id2name[price.customerGroup.id]}"
      channelKeyPart = ''
      if price.channel and _.has(@channelService.id2key, price.channel.id)
        channelKeyPart = "##{@channelService.id2key[price.channel.id]}"
      acc + "#{countryPart}#{price.value.currencyCode} #{price.value.centAmount}#{customerGroupPart}#{channelKeyPart}"
    , '')

  _mapMoney: (money) ->
    "#{money.currencyCode} #{money.centAmount}"

  _mapImages: (images) ->
    _.reduce(images, (acc, image, index) ->
      acc += CONS.DELIM_MULTI_VALUE unless index is 0
      acc + image.url
    , '')

  _mapAttribute: (attribute, attributeTypeDef) ->
    switch attributeTypeDef.name
      when CONS.ATTRIBUTE_TYPE_SET then @_mapSetAttribute(attribute, attributeTypeDef)
      when CONS.ATTRIBUTE_TYPE_ENUM, CONS.ATTRIBUTE_TYPE_LENUM then attribute.value.key
      when CONS.ATTRIBUTE_TYPE_MONEY then @_mapMoney attribute.value
      else attribute.value

  _mapLocalizedAttribute: (attribute, productType, row) ->
    h2i = @header.productTypeAttributeToIndex productType, attribute
    if h2i
      for lang, index of h2i
        if attribute.value
          row[index] = attribute.value[lang]

    row

  _mapSetAttribute: (attribute, attributeTypeDef) ->
    switch attributeTypeDef.elementType.name
      when CONS.ATTRIBUTE_TYPE_ENUM, CONS.ATTRIBUTE_TYPE_LENUM
        _.reduce(attribute.value, (memo, val, index) ->
          memo += CONS.DELIM_MULTI_VALUE unless index is 0
          memo + val.key
        , '')
      when CONS.ATTRIBUTE_TYPE_MONEY
        _.reduce(attribute.value, (memo, val, index) ->
          memo += CONS.DELIM_MULTI_VALUE unless index is 0
          memo + _mapMoney val
        , '')
      else
        attribute.value.join CONS.DELIM_MULTI_VALUE


module.exports = ExportMapping
