_ = require('underscore')._
CONS = require '../lib/constants'

class Mapping
  constructor: (options = {}) ->
    @types = options.types
    @validator = options.validator
    @errors = []

  mapProduct: (raw, productType) ->
    productType or= raw.master[@header.toIndex()[CONS.HEADER_PRODUCT_TYPE]]
    rowIndex = raw.startRow

    product = @mapBaseProduct raw.master, productType
    product.masterVariant = @mapVariant raw.master, productType, rowIndex
    for rawVariant in raw.variants
      rowIndex += 1
      product.variants.push @mapVariant rawVariant, productType, rowIndex
    product

  mapBaseProduct: (rawMaster, productType) ->
    product =
      productType:
        typeId: 'product-type'
        id: productType.id
      masterVariant: {}
      variants: []
      categories: []

    for attribName in CONS.BASE_LOCALIZED_HEADERS
      val = @mapLocalizedAttrib rawMaster, attribName, @validator.header.toLanguageIndex()
      product[attribName] = val if val

    product

  mapVariant: (rawVariant, productType, rowIndex) ->
    variant =
      prices: []
      attributes: []

    # TODO: sku

    languageHeader2Index = @header._productTypeLanguageIndexes productType
    for attribute in productType.attributes
      variant.attributes.push @mapAttribute rawVariant, attribute, languageHeader2Index

    # TODO: prices
    # TODO: images, but store them extra as we will distingush between upload, download or external

    variant

  mapAttribute: (rawVariant, attribute, languageHeader2Index) ->
    attribute =
      name: attribute.name
      value: @mapValue rawVariant, attribute, languageHeader2Index

  mapValue: (rawVariant, attribute, languageHeader2Index) ->
    if attribute.type is CONS.ATTRIBUTE_TYPE_LTEXT
      @mapLocalizedAttrib rawVariant, attribute.name, languageHeader2Index
    else
      rawVariant[@header.toIndex()[attribute.name]]

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
  mapLocalizedAttrib: (row, attribName, langH2i) ->
    values = {}
    if _.has langH2i, attribName
      _.each langH2i[attribName], (index, language) ->
        values[language] = row[index]
    # fall back if language columns could not be found
    if _.size(values) is 0
      return undefined unless _.has @header.toIndex(), attribName
      val = row[@header.toIndex()[attribName]]
      values[CONS.DEFAULT_LANGUAGE] = val
    values

module.exports = Mapping
