_ = require 'underscore'
_.mixin require('underscore.string').exports()
CONS = require './constants'
GLOBALS = require './globals'

# TODO:
# - JSDoc
# - no services!!!
# - utils only
class ExportMapping

  constructor: (options = {}) ->
    @typesService = options.typesService
    @categoryService = options.categoryService
    @channelService = options.channelService
    @stateService = options.stateService
    @customerGroupService = options.customerGroupService
    @taxService = options.taxService
    @header = options.header
    @fillAllRows = options.fillAllRows
    @onlyMasterVariants = options.onlyMasterVariants || false
    @categoryBy = options.categoryBy
    @categoryOrderHintBy = options.categoryOrderHintBy

  mapProduct: (product, productTypes) ->
    productType = productTypes[@typesService.id2index[product.productType.id]]
    rows = []
    productRow = @_mapBaseProduct product, productType
    if product.masterVariant
      rows.push productRow

    if not @onlyMasterVariants and product.variants
      for variant in product.variants
        variantRow = if @fillAllRows
          _.deepClone productRow
        else
          []
        rows.push @_mapVariant variant, productType, variantRow

    rows

  createTemplate: (productType, languages = [GLOBALS.DEFAULT_LANGUAGE]) ->
    header = [ CONS.HEADER_PUBLISHED, CONS.HEADER_HAS_STAGED_CHANGES ].concat(CONS.BASE_HEADERS.concat(CONS.SPECIAL_HEADERS))
    _.each CONS.BASE_LOCALIZED_HEADERS, (locBaseAttrib) ->
      header = header.concat _.map languages, (lang) ->
        "#{locBaseAttrib}#{GLOBALS.DELIM_HEADER_LANGUAGE}#{lang}"
    _.each productType.attributes, (attribute) =>
      switch attribute.type.name
        when CONS.ATTRIBUTE_TYPE_SET then header = header.concat @_mapAttributeTypeDef attribute.type.elementType, attribute, languages
        else header = header.concat @_mapAttributeTypeDef attribute.type, attribute, languages
    header

  _mapAttributeTypeDef: (attributeTypeDef, attribute, languages) ->
    switch attributeTypeDef.name
      when CONS.ATTRIBUTE_TYPE_LTEXT then _.map languages, (lang) -> "#{attribute.name}#{GLOBALS.DELIM_HEADER_LANGUAGE}#{lang}"
      else [ attribute.name ]

  _mapBaseProduct: (product, productType) ->
    row = if product.masterVariant
      @_mapVariant product.masterVariant, productType
    else
      []

    if @header.has(CONS.HEADER_PUBLISHED)
      row[@header.toIndex CONS.HEADER_PUBLISHED] = "#{product.published}"

    if @header.has(CONS.HEADER_HAS_STAGED_CHANGES)
      row[@header.toIndex CONS.HEADER_HAS_STAGED_CHANGES] = "#{product.hasStagedChanges}"

    if @header.has(CONS.HEADER_ID)
      row[@header.toIndex CONS.HEADER_ID] = product.id

    if @header.has(CONS.HEADER_KEY)
      row[@header.toIndex CONS.HEADER_KEY] = product.key

    if @header.has(CONS.HEADER_STATE) and _.has(product, 'state')
      if _.has @stateService.id2key, product.state.id
        row[@header.toIndex CONS.HEADER_STATE] = @stateService.id2key[product.state.id]

    if @header.has(CONS.HEADER_PRODUCT_TYPE)
      row[@header.toIndex CONS.HEADER_PRODUCT_TYPE] = productType.name

    if @header.has(CONS.HEADER_TAX) and _.has(product, 'taxCategory')
      if _.has @taxService.id2name, product.taxCategory.id
        row[@header.toIndex CONS.HEADER_TAX] = @taxService.id2name[product.taxCategory.id]

    if @header.has(CONS.HEADER_CATEGORIES)
      row[@header.toIndex CONS.HEADER_CATEGORIES] = _.reduce(product.categories or [], (memo, category, index) =>
        memo += GLOBALS.DELIM_MULTI_VALUE unless index is 0
        memo + if @categoryBy is CONS.HEADER_SLUG
          @categoryService.id2slug[category.id]
        else if @categoryBy is CONS.HEADER_EXTERNAL_ID
          @categoryService.id2externalId[category.id]
        else
          @categoryService.id2fqName[category.id]
      , '')

    if @header.has(CONS.HEADER_CREATED_AT)
      row[@header.toIndex CONS.HEADER_CREATED_AT] = product.createdAt

    if @header.has(CONS.HEADER_LAST_MODIFIED_AT)
      row[@header.toIndex CONS.HEADER_LAST_MODIFIED_AT] = product.lastModifiedAt

    for attribName, h2i of @header.toLanguageIndex()
      for lang, index of h2i
        if product[attribName]
          if attribName is CONS.HEADER_SEARCH_KEYWORDS
            row[index] = _.reduce(product[attribName][lang], (memo, val, index) ->
              memo += GLOBALS.DELIM_MULTI_VALUE unless index is 0
              memo + val.text
            , '')
          else
            row[index] = product[attribName][lang]

    if @header.has(CONS.HEADER_CATEGORY_ORDER_HINTS)
      if product.categoryOrderHints?
        categoryIds = Object.keys product.categoryOrderHints
        categoryOrderHints = _.map categoryIds, (categoryId) =>
          categoryIdentificator = categoryId
          if @categoryOrderHintBy == 'externalId'
            categoryIdentificator = @categoryService.id2externalId[categoryId]
          return "#{categoryIdentificator}:#{product.categoryOrderHints[categoryId]}"
        row[@header.toIndex CONS.HEADER_CATEGORY_ORDER_HINTS] = categoryOrderHints.join GLOBALS.DELIM_MULTI_VALUE
      else
        row[@header.toIndex CONS.HEADER_CATEGORY_ORDER_HINTS] = ''

    row

  _mapVariant: (variant, productType, row = []) ->
    if @header.has(CONS.HEADER_VARIANT_ID)
      row[@header.toIndex CONS.HEADER_VARIANT_ID] = variant.id

    if @header.has(CONS.HEADER_VARIANT_KEY)
      row[@header.toIndex CONS.HEADER_VARIANT_KEY] = variant.key

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
        else if attributeTypeDef.name is CONS.ATTRIBUTE_TYPE_SET and attributeTypeDef.elementType?.name is CONS.ATTRIBUTE_TYPE_LENUM
          # we need special treatment for set of lenums
          row = @_mapSetOfLenum(attribute, productType, row)
        else if attributeTypeDef.name is CONS.ATTRIBUTE_TYPE_SET and attributeTypeDef.elementType?.name is CONS.ATTRIBUTE_TYPE_LTEXT
          row = @_mapSetOfLtext(attribute, productType, row)
        else if attributeTypeDef.name is CONS.ATTRIBUTE_TYPE_LENUM  # we need special treatnemt for lenums
          row = @_mapLenum(attribute, productType, row)
        else if @header.has attribute.name
          row[@header.toIndex attribute.name] = @_mapAttribute(attribute, attributeTypeDef)

    row

  _mapPrices: (prices) ->
    _.reduce(prices, (acc, price, index) =>
      acc += GLOBALS.DELIM_MULTI_VALUE unless index is 0
      countryPart = ''
      if price.country
        countryPart = "#{price.country}-"
      customerGroupPart = ''
      if price.customerGroup and _.has(@customerGroupService.id2name, price.customerGroup.id)
        customerGroupPart = " #{@customerGroupService.id2name[price.customerGroup.id]}"
      channelKeyPart = ''
      if price.channel and _.has(@channelService.id2key, price.channel.id)
        channelKeyPart = "##{@channelService.id2key[price.channel.id]}"
      discountedPricePart = ''

      validFromPart = ''
      if price.validFrom
        validFromPart = "$#{price.validFrom}"

      validUntilPart = ''
      if price.validUntil
        validUntilPart = "~#{price.validUntil}"

      tiersPart = ''
      if price.tiers
        tiersPart = "%#{@_mapTiers price.tiers}"

      if price.discounted?
        discountedPricePart = "|#{price.discounted.value.centAmount}"
      acc + "#{countryPart}#{price.value.currencyCode} #{price.value.centAmount}#{discountedPricePart}#{customerGroupPart}#{channelKeyPart}#{validFromPart}#{validUntilPart}#{tiersPart}"
    , '')

  _mapTiers: (tiers) ->
    _.reduce(tiers, (acc, priceTier, index) ->
      acc += GLOBALS.DELIM_TIERS_MULTI_VALUE unless index is 0
      acc + "#{priceTier.value.currencyCode} #{priceTier.value.centAmount} @#{priceTier.minimumQuantity}"
    , '')

  _mapMoney: (money) ->
    "#{money.currencyCode} #{money.centAmount}"

  _mapImages: (images) ->
    _.reduce(images, (acc, image, index) ->
      acc += GLOBALS.DELIM_MULTI_VALUE unless index is 0
      acc + image.url + GLOBALS.DELIM_URL_ATTRIBUTES_SEPERATOR +
      (image.label || "") + GLOBALS.DELIM_URL_ATTRIBUTES_SEPERATOR + (image?.dimensions?.w || 0)+
      GLOBALS.DELIM_DIMENSIONS_SEPERATOR + (image?.dimensions?.h || 0)
    , '')

  _mapAttribute: (attribute, attributeTypeDef) ->
    switch attributeTypeDef.name
      when CONS.ATTRIBUTE_TYPE_SET then @_mapSetAttribute(attribute, attributeTypeDef)
      when CONS.ATTRIBUTE_TYPE_ENUM then attribute.value.key
      when CONS.ATTRIBUTE_TYPE_MONEY then @_mapMoney attribute.value
      when CONS.ATTRIBUTE_TYPE_REFERENCE then attribute.value?.id
      when CONS.ATTRIBUTE_TYPE_BOOLEAN then attribute.value.toString()
      else attribute.value

  _mapLocalizedAttribute: (attribute, productType, row) ->
    h2i = @header.productTypeAttributeToIndex productType, attribute
    if h2i
      for lang, index of h2i
        if attribute.value
          row[index] = attribute.value[lang]
    row

  _mapLenum: (attribute, productType, row) ->
    noneLangIndex = @header.toIndex(attribute.name)
    # if my attribute has no language index, I want the key only
    if noneLangIndex
      row[noneLangIndex] = attribute.value.key
    h2i = @header.productTypeAttributeToIndex productType, attribute
    if h2i
      for lang, index of h2i
        if attribute.value
          row[index] = attribute.value.label[lang]
        else
          row[index] = attribute.value.key
    row

  _mapSetOfLenum: (attribute, productType, row) ->
    # if my attribute has no language index, I want the keys only
    noneLangIndex = @header.toIndex(attribute.name)
    if noneLangIndex
      row[noneLangIndex] = _.reduce(attribute.value, (memo, val, index) ->
        memo += GLOBALS.DELIM_MULTI_VALUE unless index is 0
        memo + val.key
      , '')
    h2i = @header.productTypeAttributeToIndex productType, attribute
    if h2i
      for lang, index of h2i
        if attribute.value
          row[index] = _.reduce(attribute.value, (memo, val, index) ->
            memo += GLOBALS.DELIM_MULTI_VALUE unless index is 0
            memo + val.label[lang]
          , '')
        else
          row[index] = attribute.value.key

    row

  _mapSetOfLtext: (attribute, productType, row) ->
    h2i = @header.productTypeAttributeToIndex productType, attribute
    for lang, index of h2i
      row[index] = _.reduce(attribute.value, (memo, val, index) ->
        return memo unless val[lang]?

        memo += GLOBALS.DELIM_MULTI_VALUE unless index is 0
        memo + val[lang]
      , '')
    row

  _mapSetAttribute: (attribute, attributeTypeDef) ->
    switch attributeTypeDef.elementType.name
      when CONS.ATTRIBUTE_TYPE_ENUM
        _.reduce(attribute.value, (memo, val, index) ->
          memo += GLOBALS.DELIM_MULTI_VALUE unless index is 0
          memo + val.key
        , '')
      when CONS.ATTRIBUTE_TYPE_MONEY
        _.reduce(attribute.value, (memo, val, index) =>
          memo += GLOBALS.DELIM_MULTI_VALUE unless index is 0
          memo + @_mapMoney val
        , '')
      else
        attribute.value.join GLOBALS.DELIM_MULTI_VALUE


module.exports = ExportMapping
