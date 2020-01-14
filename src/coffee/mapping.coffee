_ = require 'underscore'
_.mixin require('underscore.string').exports()
CONS = require './constants'
GLOBALS = require './globals'

# TODO:
# - JSDoc
# - no services!!!
# - utils only
class Mapping

  constructor: (options = {}) ->
    @types = options.types
    @customerGroups = options.customerGroups
    @categories = options.categories
    @taxes = options.taxes
    @states = options.states
    @channels = options.channels
    @continueOnProblems = options.continueOnProblems
    @errors = []

  mapProduct: (raw, productType) ->
    productType or= raw.master[@header.toIndex CONS.HEADER_PRODUCT_TYPE]
    rowIndex = raw.startRow

    product = @mapBaseProduct raw.master, productType, rowIndex
    product.masterVariant = @mapVariant raw.master, 1, productType, rowIndex, product
    _.each raw.variants, (entry, index) =>
      product.variants.push @mapVariant entry.variant, index + 2, productType, entry.rowIndex, product

    data =
      product: product
      rowIndex: raw.startRow
      header: @header
      publish: raw.publish
    data

  mapBaseProduct: (rawMaster, productType, rowIndex) ->
    product =
      productType:
        typeId: 'product-type'
        id: productType.id
      masterVariant: {}
      variants: []

    if @header.has(CONS.HEADER_ID)
      product.id = rawMaster[@header.toIndex CONS.HEADER_ID]
    if @header.has(CONS.HEADER_KEY)
      product.key = rawMaster[@header.toIndex CONS.HEADER_KEY]
    if @header.has(CONS.HEADER_META_TITLE)
      product.metaTitle = rawMaster[@header.toIndex CONS.HEADER_META_TITLE] or {}
    if @header.has(CONS.HEADER_META_DESCRIPTION)
      product.metaDescription = rawMaster[@header.toIndex CONS.HEADER_META_DESCRIPTION] or {}
    if @header.has(CONS.HEADER_META_KEYWORDS)
      product.metaKeywords = rawMaster[@header.toIndex CONS.HEADER_META_KEYWORDS] or {}
    if @header.has(CONS.HEADER_SEARCH_KEYWORDS)
      product.searchKeywords = rawMaster[@header.toIndex CONS.HEADER_SEARCH_KEYWORDS] or {}

    product.categories = @mapCategories rawMaster, rowIndex
    tax = @mapTaxCategory rawMaster, rowIndex
    product.taxCategory = tax if tax
    state = @mapState rawMaster, rowIndex
    product.state = state if state
    product.categoryOrderHints = @mapCategoryOrderHints rawMaster, rowIndex

    for attribName in CONS.BASE_LOCALIZED_HEADERS
      if attribName is CONS.HEADER_SEARCH_KEYWORDS
        val = @mapSearchKeywords rawMaster, attribName,  @header.toLanguageIndex()
      else
        val = @mapLocalizedAttrib rawMaster, attribName, @header.toLanguageIndex()
      product[attribName] = val if val

    unless product.slug
      product.slug = {}
      if product.name? and product.name[GLOBALS.DEFAULT_LANGUAGE]?
        product.slug[GLOBALS.DEFAULT_LANGUAGE] = @ensureValidSlug(_.slugify product.name[GLOBALS.DEFAULT_LANGUAGE], rowIndex)
    product

  ensureValidSlug: (slug, rowIndex, appendix = '') ->
    unless _.isString(slug) and slug.length > 2
      @errors.push "[row #{rowIndex}:#{CONS.HEADER_SLUG}] Can't generate valid slug out of '#{slug}'! If you did not provide slug in your file, please do so as slug could not be auto-generated from the product name given."
      return
    @slugs or= []
    currentSlug = "#{slug}#{appendix}"
    unless _.contains(@slugs, currentSlug)
      @slugs.push currentSlug
      return currentSlug
    @ensureValidSlug slug, rowIndex, Math.floor((Math.random() * 89999) + 10001) # five digets

  hasValidValueForHeader: (row, headerName) ->
    return false unless @header.has(headerName)
    @isValidValue(row[@header.toIndex headerName])

  isValidValue: (rawValue) ->
    return _.isString(rawValue) and rawValue.length > 0

  mapCategories: (rawMaster, rowIndex) ->
    categories = []
    return categories unless @hasValidValueForHeader(rawMaster, CONS.HEADER_CATEGORIES)
    rawCategories = rawMaster[@header.toIndex CONS.HEADER_CATEGORIES].split GLOBALS.DELIM_MULTI_VALUE
    for rawCategory in rawCategories
      cat =
        typeId: 'category'
      if _.has(@categories.externalId2id, rawCategory)
        cat.id = @categories.externalId2id[rawCategory]
      else if _.has(@categories.fqName2id, rawCategory)
        cat.id = @categories.fqName2id[rawCategory]
      else if _.has(@categories.name2id, rawCategory)
        if _.contains(@categories.duplicateNames, rawCategory)
          msg =  "[row #{rowIndex}:#{CONS.HEADER_CATEGORIES}] The category '#{rawCategory}' is not unqiue!"
          if @continueOnProblems
            console.warn msg
          else
            @errors.push msg
        else
          cat.id = @categories.name2id[rawCategory]

      if cat.id
        categories.push cat

      else
        msg = "[row #{rowIndex}:#{CONS.HEADER_CATEGORIES}] Can not find category for '#{rawCategory}'!"
        if @continueOnProblems
          console.warn msg
        else
          @errors.push msg

    categories

  # parses the categoryOrderHints column for a given row
  mapCategoryOrderHints: (rawMaster, rowIndex) ->
    catOrderHints = {}
    # check if there actually is something to parse in the column
    return catOrderHints unless @hasValidValueForHeader(rawMaster, CONS.HEADER_CATEGORY_ORDER_HINTS)
    # parse the value to get a list of all catOrderHints
    rawCatOrderHints = rawMaster[@header.toIndex CONS.HEADER_CATEGORY_ORDER_HINTS].split GLOBALS.DELIM_MULTI_VALUE
    _.each rawCatOrderHints, (rawCatOrderHint) =>
      # extract the category id and the order hint from the raw value
      [rawCatId, rawOrderHint] = rawCatOrderHint.split ':'
      orderHint = parseFloat(rawOrderHint)
      # check if the product is actually assigned to the category
      catId =
        if _.has(@categories.id2fqName, rawCatId)
          rawCatId
        else if _.has(@categories.externalId2id, rawCatId)
          @categories.externalId2id[rawCatId]
        # in case the category was provided as the category name
        # check if the product is actually assigend to the category
        else if _.has(@categories.name2id, rawCatId)
          # get the actual category id instead of the category name
          @categories.name2id[rawCatId]
        # in case the category was provided using the category slug
        else if _.contains(@categories.id2slug, rawCatId)
          # get the actual category id instead of the category name
          _.findKey @categories.id2slug, (slug) ->
            slug == rawCatId
        else
          msg = "[row #{rowIndex}:#{CONS.HEADER_CATEGORY_ORDER_HINTS}] Can not find category for ID '#{rawCatId}'!"
          if @continueOnProblems
            console.warn msg
          else
            @errors.push msg
          null

      if orderHint == NaN
        msg = "[row #{rowIndex}:#{CONS.HEADER_CATEGORY_ORDER_HINTS}] Order hint has to be a valid number!"
        if @continueOnProblems
          console.warn msg
        else
          @errors.push msg
      else if !(orderHint > 0 && orderHint < 1)
        msg = "[row #{rowIndex}:#{CONS.HEADER_CATEGORY_ORDER_HINTS}] Order hint has to be < 1 and > 0 but was '#{orderHint}'!"
        if @continueOnProblems
          console.warn msg
        else
          @errors.push msg
      else
        if catId
          # orderHint and catId are ensured to be valid
          catOrderHints[catId] = orderHint.toString()

    catOrderHints


  mapTaxCategory: (rawMaster, rowIndex) ->
    return unless @hasValidValueForHeader(rawMaster, CONS.HEADER_TAX)
    rawTax = rawMaster[@header.toIndex CONS.HEADER_TAX]
    if _.contains(@taxes.duplicateNames, rawTax)
      @errors.push "[row #{rowIndex}:#{CONS.HEADER_TAX}] The tax category '#{rawTax}' is not unqiue!"
      return
    unless _.has(@taxes.name2id, rawTax)
      @errors.push "[row #{rowIndex}:#{CONS.HEADER_TAX}] The tax category '#{rawTax}' is unknown!"
      return

    tax =
      typeId: 'tax-category'
      id: @taxes.name2id[rawTax]

  mapState: (rawMaster, rowIndex) ->
    return unless @hasValidValueForHeader(rawMaster, CONS.HEADER_STATE)
    rawState = rawMaster[@header.toIndex CONS.HEADER_STATE]
    if _.contains(@states.duplicateKeys, rawState)
      @errors.push "[row #{rowIndex}:#{CONS.HEADER_STATE}] The state '#{rawState}' is not unqiue!"
      return
    unless _.has(@states.key2id, rawState)
      @errors.push "[row #{rowIndex}:#{CONS.HEADER_STATE}] The state '#{rawState}' is unknown!"
      return

    state =
      typeId: 'state'
      id: @states.key2id[rawState]

  mapVariant: (rawVariant, variantId, productType, rowIndex, product) ->
    if variantId > 2 and @header.has(CONS.HEADER_VARIANT_ID)
      vId = @mapInteger rawVariant[@header.toIndex CONS.HEADER_VARIANT_ID], CONS.HEADER_VARIANT_ID, rowIndex
      if vId? and not _.isNaN vId
        variantId = vId
      else
        # we have no valid variant id - mapInteger already mentioned this as error
        return

    variant =
      id: variantId
      attributes: []

    if @header.has(CONS.HEADER_VARIANT_KEY)
      variant.key = rawVariant[@header.toIndex CONS.HEADER_VARIANT_KEY]

    variant.sku = rawVariant[@header.toIndex CONS.HEADER_SKU] if @header.has CONS.HEADER_SKU

    languageHeader2Index = @header._productTypeLanguageIndexes productType
    if productType.attributes
      for attribute in productType.attributes
        attrib = if attribute.attributeConstraint is CONS.ATTRIBUTE_CONSTRAINT_SAME_FOR_ALL and variantId > 1
          _.find product.masterVariant.attributes, (a) ->
            a.name is attribute.name
        else
          @mapAttribute rawVariant, attribute, languageHeader2Index, rowIndex
        variant.attributes.push attrib if attrib

    variant.prices = @mapPrices rawVariant[@header.toIndex CONS.HEADER_PRICES], rowIndex
    variant.images = @mapImages rawVariant, variantId, rowIndex

    variant

  mapAttribute: (rawVariant, attribute, languageHeader2Index, rowIndex) ->
    # if attribute conflicts with some base product property prefix it with "attribute." string
    prefixedAttributeName = if attribute.name in CONS.PRODUCT_LEVEL_PROPERTIES.concat(CONS.ALL_HEADERS)
      "attribute.#{attribute.name}"
    else
      attribute.name

    value = @mapValue rawVariant, prefixedAttributeName, attribute, languageHeader2Index, rowIndex
    return undefined if _.isUndefined(value) or (_.isObject(value) and _.isEmpty(value)) or (_.isString(value) and _.isEmpty(value))
    attribute =
      name: attribute.name
      value: value
    attribute

  mapValue: (rawVariant, attributeName, attribute, languageHeader2Index, rowIndex) ->
    switch attribute.type.name
      when CONS.ATTRIBUTE_TYPE_SET then @mapSetAttribute rawVariant, attributeName, attribute.type.elementType, languageHeader2Index, rowIndex
      when CONS.ATTRIBUTE_TYPE_LTEXT then @mapLocalizedAttrib rawVariant, attributeName, languageHeader2Index
      when CONS.ATTRIBUTE_TYPE_NUMBER then @mapNumber rawVariant[@header.toIndex attributeName], attribute.name, rowIndex
      when CONS.ATTRIBUTE_TYPE_BOOLEAN then @mapBoolean rawVariant[@header.toIndex attributeName], attribute.name, rowIndex
      when CONS.ATTRIBUTE_TYPE_MONEY then @mapMoney rawVariant[@header.toIndex attributeName], attribute.name, rowIndex
      when CONS.ATTRIBUTE_TYPE_REFERENCE then @mapReference rawVariant[@header.toIndex attributeName], attribute.type
      when CONS.ATTRIBUTE_TYPE_ENUM then @mapEnumAttribute rawVariant[@header.toIndex attributeName], attribute.type.values
      when CONS.ATTRIBUTE_TYPE_LENUM then @mapEnumAttribute rawVariant[@header.toIndex attributeName], attribute.type.values
      else rawVariant[@header.toIndex attributeName] # works for text

  mapEnumAttribute: (enumKey, enumValues) ->
    if enumKey
      _.find enumValues, (value) -> value.key is enumKey

  mapSetAttribute: (rawVariant, attributeName, elementType, languageHeader2Index, rowIndex) ->
    if elementType.name is CONS.ATTRIBUTE_TYPE_LTEXT
      multiValObj = @mapLocalizedAttrib rawVariant, attributeName, languageHeader2Index
      value = []
      _.each multiValObj, (raw, lang) =>
        if @isValidValue(raw)
          languageVals = raw.split GLOBALS.DELIM_MULTI_VALUE
          _.each languageVals, (v, index) ->
            localized = {}
            localized[lang] = v
            value[index] = _.extend (value[index] or {}), localized
      value
    else
      raw = rawVariant[@header.toIndex attributeName]
      if @isValidValue(raw)
        rawValues = raw.split GLOBALS.DELIM_MULTI_VALUE
        _.map rawValues, (rawValue) =>
          switch elementType.name
            when CONS.ATTRIBUTE_TYPE_MONEY
              @mapMoney rawValue, attributeName, rowIndex
            when CONS.ATTRIBUTE_TYPE_NUMBER
              @mapNumber rawValue, attributeName, rowIndex
            when CONS.ATTRIBUTE_TYPE_BOOLEAN
              @mapBoolean rawValue, attributeName, rowIndex
            when CONS.ATTRIBUTE_TYPE_ENUM
              @mapEnumAttribute rawValue, elementType.values
            when CONS.ATTRIBUTE_TYPE_LENUM
              @mapEnumAttribute rawValue, elementType.values
            when CONS.ATTRIBUTE_TYPE_REFERENCE
              @mapReference rawValue, elementType
            else
              rawValue

  mapPrices: (raw, rowIndex) ->
    prices = []
    return prices unless @isValidValue(raw)
    rawPrices = raw.split GLOBALS.DELIM_MULTI_VALUE
    for rawPrice in rawPrices
      matchedPrice = CONS.REGEX_PRICE.exec rawPrice
      unless matchedPrice
        @errors.push "[row #{rowIndex}:#{CONS.HEADER_PRICES}] Can not parse price '#{rawPrice}'!"
        continue

      country = matchedPrice[2]
      currencyCode = matchedPrice[3]
      centAmount = matchedPrice[4]
      customerGroupName = matchedPrice[8]
      channelKey = matchedPrice[10]
      validFrom = matchedPrice[12]
      validUntil = matchedPrice[14]
      tiers = matchedPrice[16]
      price =
        value: @mapMoney "#{currencyCode} #{centAmount}", CONS.HEADER_PRICES, rowIndex
      price.validFrom = validFrom if validFrom
      price.validUntil = validUntil if validUntil
      price.country = country if country
      price.tiers = @mapTiers tiers if tiers

      if customerGroupName
        unless _.has(@customerGroups.name2id, customerGroupName)
          @errors.push "[row #{rowIndex}:#{CONS.HEADER_PRICES}] Can not find customer group '#{customerGroupName}'!"
          return []
        price.customerGroup =
          typeId: 'customer-group'
          id: @customerGroups.name2id[customerGroupName]
      if channelKey
        unless _.has(@channels.key2id, channelKey)
          @errors.push "[row #{rowIndex}:#{CONS.HEADER_PRICES}] Can not find channel with key '#{channelKey}'!"
          return []
        price.channel =
          typeId: 'channel'
          id: @channels.key2id[channelKey]

      prices.push price

    prices

  mapTiers: (tiers) ->
    unless tiers
      return []
    tiers.split(GLOBALS.DELIM_TIERS_MULTI_VALUE).map((priceTier) ->
      matchedPriceTier = priceTier.split(/ |@/g)
      formattedTier =
        value:
          currencyCode: matchedPriceTier[0]
          centAmount: parseInt matchedPriceTier[1], 10
        minimumQuantity: parseInt matchedPriceTier[3], 10
    )

  # EUR 300
  # USD 999
  mapMoney: (rawMoney, attribName, rowIndex) ->
    return unless @isValidValue(rawMoney)
    matchedMoney = CONS.REGEX_MONEY.exec rawMoney
    unless matchedMoney
      @errors.push "[row #{rowIndex}:#{attribName}] Can not parse money '#{rawMoney}'!"
      return
    # TODO: check for correct currencyCode

    money =
      currencyCode: matchedMoney[1]
      centAmount: parseInt matchedMoney[2]

  mapReference: (rawReference, attributeType) ->
    return undefined unless rawReference
    ref =
      id: rawReference
      typeId: attributeType.referenceTypeId

  mapInteger: (rawNumber, attribName, rowIndex) ->
    parseInt @mapNumber(rawNumber, attribName, rowIndex, CONS.REGEX_INTEGER)

  mapNumber: (rawNumber, attribName, rowIndex, regEx = CONS.REGEX_FLOAT) ->
    return unless @isValidValue(rawNumber)
    matchedNumber = regEx.exec rawNumber
    unless matchedNumber
      @errors.push "[row #{rowIndex}:#{attribName}] The number '#{rawNumber}' isn't valid!"
      return
    parseFloat matchedNumber[0]

  mapBoolean: (rawBoolean, attribName, rowIndex) ->
    if _.isUndefined(rawBoolean) or (_.isString(rawBoolean) and _.isEmpty(rawBoolean))
      return
    errorMsg = "[row #{rowIndex}:#{attribName}] The value '#{rawBoolean}' isn't a valid boolean!"
    try
      b = JSON.parse(rawBoolean.toLowerCase())
      if _.isBoolean(b) or b == 0 or b == 1
        return Boolean(b)
      else
        @errors.push errorMsg
        return
    catch
      @errors.push errorMsg

  # "a.en,a.de,a.it"
  # "hi,Hallo,ciao"
  # values:
  #   de: 'Hallo'
  #   en: 'hi'
  #   it: 'ciao'
  mapLocalizedAttrib: (row, attribName, langH2i) ->
    values = {}
    if _.has langH2i, attribName
      _.each langH2i[attribName], (index, language) ->
        val = row[index]
        values[language] = val if val
    # fall back to non localized column if language columns could not be found
    if _.size(values) is 0
      return unless @header.has(attribName)
      val = row[@header.toIndex attribName]
      values[GLOBALS.DEFAULT_LANGUAGE] = val if val

    return if _.isEmpty values
    values

  # "a.en,a.de,a.it"
  # "hi,Hallo,ciao"
  # values:
  #   de: 'Hallo'
  #   en: 'hi'
  #   it: 'ciao'
  mapSearchKeywords: (row, attribName, langH2i) ->
    values = {}
    if _.has langH2i, attribName
      _.each langH2i[attribName], (index, language) ->
        val = row[index]
        if not _.isString(val) || val == ""
          return

        singleValues = val.split GLOBALS.DELIM_MULTI_VALUE
        texts = []
        _.each singleValues, (v, index) ->
          texts.push { text: v}
        values[language] = texts
    # fall back to non localized column if language columns could not be found
    if _.size(values) is 0
      return unless @header.has(attribName)
      val = row[@header.toIndex attribName]
      values[GLOBALS.DEFAULT_LANGUAGE].text = val if val

    return if _.isEmpty values
    values

  mapImages: (rawVariant, variantId, rowIndex) ->
    images = []
    return images unless @hasValidValueForHeader(rawVariant, CONS.HEADER_IMAGES)
    rawImages = rawVariant[@header.toIndex CONS.HEADER_IMAGES].split GLOBALS.DELIM_MULTI_VALUE

    for rawImage in rawImages
      # Url Example :- https://jeanscentre-static.joggroup.net/sys|BundleThumb|200x200
      imageAttributes = rawImage.split GLOBALS.DELIM_URL_ATTRIBUTES_SEPERATOR
      dimensions = (imageAttributes[2] || "").split GLOBALS.DELIM_DIMENSIONS_SEPERATOR
      width = dimensions[0]
      height = dimensions[1]
      image =
        url: imageAttributes[0]
        dimensions:
          w: if isNaN(width) then 0 else Number width
          h: if isNaN(height) then 0 else Number height
        label: imageAttributes[1] || ""
      images.push image

    images


module.exports = Mapping
