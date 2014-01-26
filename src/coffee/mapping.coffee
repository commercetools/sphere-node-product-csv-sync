_ = require('underscore')._
_s = require 'underscore.string'
CONS = require '../lib/constants'

class Mapping
  constructor: (options = {}) ->
    @types = options.types
    @errors = []

  mapProduct: (raw, productType) ->
    productType or= raw.master[@header.toIndex CONS.HEADER_PRODUCT_TYPE]
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
      val = @mapLocalizedAttrib rawMaster, attribName, @header.toLanguageIndex()
      product[attribName] = val if val

    unless product.slug
      product.slug = {}
      product.slug[CONS.DEFAULT_LANGUAGE] = _s.slugify product.name[CONS.DEFAULT_LANGUAGE]
      # TODO: ensure slug is valid

    product

  mapVariant: (rawVariant, productType, rowIndex) ->
    variant =
      prices: []
      attributes: []

    variant.sku = rawVariant[@header.toIndex CONS.HEADER_SKU] if @header.has CONS.HEADER_SKU

    languageHeader2Index = @header._productTypeLanguageIndexes productType
    for attribute in productType.attributes
      attrib = @mapAttribute rawVariant, attribute, languageHeader2Index, rowIndex
      variant.attributes.push attrib if attrib

    # TODO: prices
    # TODO: images, but store them extra as we will distingush between upload, download or external

    variant

  mapAttribute: (rawVariant, attribute, languageHeader2Index, rowIndex) ->
    value = @mapValue rawVariant, attribute, languageHeader2Index, rowIndex
    return unless value
    attribute =
      name: attribute.name
      value: value

  mapValue: (rawVariant, attribute, languageHeader2Index, rowIndex) ->
    console.log attribute.type
    switch attribute.type
      when CONS.ATTRIBUTE_TYPE_LTEXT then @mapLocalizedAttrib rawVariant, attribute.name, languageHeader2Index
#      when CONS.ATTRIBUTE_TYPE_ENUM, CONS.ATTRIBUTE_TYPE_LENUM then 'x'
      when CONS.ATTRIBUTE_TYPE_NUMBER then @mapNumber rawVariant[@header.toIndex attribute.name], attribute.name, rowIndex
      when CONS.ATTRIBUTE_TYPE_MONEY then @mapMoney rawVariant, attribute.name
      else rawVariant[@header.toIndex attribute.name]

  # EUR 300
  # DE.EUR 300
  # EN.USD 999 CG
  #
  mapPrices: (raw, rowIndex) ->
    prices = []
    rawPrices = raw.split CONS.DELIM_MULTI_VALUE
    for rawPrice in rawPrices
      money = @mapMoney rawPrice, CONS.HEADER_PRICES, rowIndex
      continue unless money
      # TODO contry
      # TODO customer group
      # TODO channel
      prices.push money
    prices

  mapMoney: (rawMoney, attribName, rowIndex) ->
    parts = rawMoney.split ' '
    if parts.length isnt 2
      @errors.push "[row #{rowIndex}] Can not parse money '#{rawMoney}'!"
      return
    amount = @mapNumber parts[1], attribName, rowIndex
    return unless amount
    # TODO: check for correct currencyCode
    price =
      money:
        currencyCode: parts[0]
        centAmount: amount

  mapNumber: (rawNumber, attribName, rowIndex) ->
    number = parseInt rawNumber
    if "#{number}" isnt rawNumber
      @errors.push "[row #{rowIndex}:#{attribName}] The number '#{rawNumber}' isn't valid!"
      return
    number

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
      return undefined unless @header.has attribName
      val = row[@header.toIndex attribName]
      values[CONS.DEFAULT_LANGUAGE] = val
    values

module.exports = Mapping
