_ = require('underscore')._
CONS = require '../lib/constants'

class Mapping
  constructor: (options = {}) ->
    @types = options.types
    @errors = []

  mapProduct: (raw, productType) ->
    productType or= raw.master[@h2i[CONS.HEADER_PRODUCT_TYPE]]
    lang_h2i = @productTypeHeaderIndex productType
    rowIndex = raw.startRow

    product = @mapBaseProduct raw.master, productType
    product.masterVariant = @mapVariant raw.master, productType, lang_h2i
    for rawVariant in raw.variants
      rowIndex += 1
      product.variants.push @mapVariant rawVariant, productType, lang_h2i, rowIndex
    product

  mapBaseProduct: (rawMaster, productType) ->
    product =
      productType:
        typeId: 'product-type'
        id: productType.id
      masterVariant: {}
      variants: []
      categories: []

    lang_h2i = @languageHeader2Index @header, CONS.BASE_LOCALIZED_HEADERS
    for attribName in CONS.BASE_LOCALIZED_HEADERS
      val = @mapLocalizedAttrib rawMaster, attribName, lang_h2i
      product[attribName] = val if val

    product

  mapVariant: (rawVariant, productType, lang_h2i, rowIndex) ->
    variant =
      prices: []
      attributes: []

    # TODO: sku

    for attribute in productType.attributes
      variant.attributes.push @mapAttribute rawVariant, attribute, lang_h2i

    # TODO: prices
    # TODO: images, but store them extra as we will distingush between upload, download or external

    variant

  mapAttribute: (rawVariant, attribute, lang_h2i) ->
    attribute =
      name: attribute.name
      value: @mapValue rawVariant, attribute

  mapValue: (rawVariant, attribute, lang_h2i) ->
    if attribute.type is CONS.ATTRIBUTE_TYPE_LTEXT #if _.has @lang_h2i, attribute.name
      mapLocalizedAttrib rawVariant, attribute.name, lang_h2i
    else
      rawVariant[@h2i[attribute.name]]

    # TODO: check type

  # EUR 300
  # DE.EUR 300
  # EN.USD 999 CG
  #
  mapPrices: (raw, rowIndex) ->
    prices = []
    rawPrices = raw.split CONS.DELIM_MULTI_VALUE
    for rawPrice in rawPrices
      parts = rawPrice.split ' '
      if parts.length isnt 2
        @errors.push "[row #{rowIndex}] Can not parse price '#{raw}'!"
        continue
      amount = parseInt parts[1]
      if "#{amount}" isnt parts[1]
        @errors.push "[row #{rowIndex}] The price amount '#{parts[1]}' isn't valid!"
        continue
      price =
        money:
          currencyCode: parts[0]
          centAmount: parseInt parts[1]
      prices.push price
    prices

  # "a.en,a.de,a.it"
  # "hi,Hallo,ciao"
  # values:
  #   de: 'Hallo'
  #   en: 'hi'
  #   it: 'ciao'
  mapLocalizedAttrib: (row, attribName, lang_h2i) ->
    values = {}
    if _.has lang_h2i, attribName
      _.each lang_h2i[attribName], (index, language) ->
        values[language] = row[index]
    # fall back if language columns could not be found
    if _.size(values) is 0
      return undefined unless _.has @h2i, attribName
      val = row[@h2i[attribName]]
      values[CONS.DEFAULT_LANGUAGE] = val
    values

  # "x,y,z"
  # header2index:
  #   x: 0
  #   y: 1
  #   z: 2
  header2index: (header) ->
    _.object _.map header, (head, index) -> [head, index]

  # "x,a1.de,foo,a1.it"
  # languageHeader2Index =
  #   a1:
  #     de: 1
  #     it: 3
  languageHeader2Index: (header, localizedAttributes) ->
    lang_h2i = {}
    for langAttribName in localizedAttributes
      for head, index in header
        parts = head.split CONS.DELIM_HEADER_LANGUAGE
        if _.size(parts) is 2
          if parts[0] is langAttribName
            lang = parts[1]
            # TODO: check language
            lang_h2i[langAttribName] or= {}
            lang_h2i[langAttribName][lang] = index

    lang_h2i

  productTypeHeaderIndex: (productType) ->
    @productTypeId2HeaderIndex or= {}
    lang_h2i = @productTypeId2HeaderIndex[productType.id]
    unless lang_h2i
      ptLanguageAttributes = _.map productType.attributes, (a) -> a.name if a.type is CONS.ATTRIBUTE_TYPE_LTEXT
      lang_h2i = @languageHeader2Index @header, ptLanguageAttributes
      @productTypeId2HeaderIndex[productType.id] = lang_h2i
    lang_h2i


module.exports = Mapping
