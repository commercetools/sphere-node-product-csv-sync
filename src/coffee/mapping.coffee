_ = require('underscore')._
CONS = require '../lib/constants'

class Mapping
  constructor: (options = {}) ->

  mapProduct: (raw) ->
    product = @mapBaseProduct raw.master
    product.masterVariant = @mapVariant raw.master
    for rawVariant in raw.variants
      product.variants.push @mapVariant rawVariant
    product

  mapBaseProduct: (rawMaster) ->
    product =
      productType:
        type: 'product-type'
      masterVariant: {}
      variants: []
      categories: []

    for attribName in CONS.BASE_LOCALIZED_HEADERS
      val = @mapLocalizedAttrib rawMaster, attribName
      product[attribName] = val if val

    product

  mapVariant: (rawVariant, productType) ->
    variant =
      prices: []
      attributes: []

    #for attribute in productType.attributes

    variant

  # "a.en,a.de,a.it"
  # "hi,Hallo,ciao"
  # values:
  #   de: 'Hallo'
  #   en: 'hi'
  #   it: 'ciao'
  mapLocalizedAttrib: (row, attribName) ->
    values = {}
    if _.has(@lang_h2i, attribName)
      _.each @lang_h2i[attribName], (index, language) ->
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

module.exports = Mapping
