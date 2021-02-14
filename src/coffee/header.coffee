_ = require 'underscore'
CONS = require './constants'
GLOBALS = require './globals'

# TODO:
# - JSDoc
# - put it under utils
class Header

  constructor: (@rawHeader) ->

  # checks some basic rules for the header row
  validate: ->
    errors = []
    if @rawHeader.length isnt _.unique(@rawHeader).length
      errors.push "There are duplicate header entries!"

    missingHeaders = _.difference [CONS.HEADER_PRODUCT_TYPE], @rawHeader
    if _.size(missingHeaders) > 0
      for missingHeader in missingHeaders
        errors.push "Can't find necessary base header '#{missingHeader}'!"

    if not _.contains(@rawHeader, CONS.HEADER_VARIANT_ID) and not _.contains(@rawHeader, CONS.HEADER_SKU)
      errors.push "You need either the column '#{CONS.HEADER_VARIANT_ID}' or '#{CONS.HEADER_SKU}' to identify your variants!"

    errors

  # "x,y,z"
  # toIndex:
  #   x: 0
  #   y: 1
  #   z: 2
  toIndex: (name) ->
    if not @h2i then @h2i = _.object _.map @rawHeader, (head, index) -> [head, index]
    return @h2i[name] if name
    @h2i

  has: (name) ->
    @toIndex() unless @h2i?
    _.has @h2i, name

  toLanguageIndex: (name) ->
    @langH2i = @_languageToIndex CONS.BASE_LOCALIZED_HEADERS unless @langH2i
    return @langH2i[name] if name
    @langH2i

  hasLanguageForBaseAttribute: (name) ->
    _.has @langH2i, name

  hasLanguageForCustomAttribute: (name) ->
    foo = _.find @productTypeId2HeaderIndex, (productTypeLangH2i) ->
      _.has productTypeLangH2i, name
    foo?

  # "a,x.de,y,x.it,z"
  # productTypeAttributeToIndex for 'x'
  #   de: 1
  #   it: 3
  productTypeAttributeToIndex: (productType, attribute) ->
    @_productTypeLanguageIndexes(productType)[attribute.name]

  # "x,a1.de,foo,a1.it"
  # _languageToIndex =
  #   a1:
  #     de: 1
  #     it: 3
  _languageToIndex: (localizedAttributes) ->
    langH2i = {}
    for langAttribName in localizedAttributes
      for head, index in @rawHeader
        parts = head.split GLOBALS.DELIM_HEADER_LANGUAGE
        if _.size(parts) >= 2
          nameRegexp = new RegExp("^#{langAttribName}\.")
          if head.match(nameRegexp) && _.first(parts) == langAttribName # because materialType override material attribute because of sub string match
            lang = _.last(parts)
            # TODO: check language
            langH2i[langAttribName] or= {}
            langH2i[langAttribName][lang] = index

    langH2i

  # Stores the map between the id of product types and the language header index
  # Lenum and Set of Lenum are now first class localised citizens
  _productTypeLanguageIndexes: (productType) ->
    @productTypeId2HeaderIndex or= {}
    langH2i = @productTypeId2HeaderIndex[productType.id]
    unless langH2i
      ptLanguageAttributes = _.map productType.attributes, (attribute) ->
        if (attribute.type.name is CONS.ATTRIBUTE_TYPE_LTEXT) or
        (attribute.type.name is CONS.ATTRIBUTE_TYPE_SET and attribute.type.elementType?.name is CONS.ATTRIBUTE_TYPE_LTEXT) or
        (attribute.type.name is CONS.ATTRIBUTE_TYPE_LENUM) or
        (attribute.type.name is CONS.ATTRIBUTE_TYPE_SET and attribute.type.elementType?.name is CONS.ATTRIBUTE_TYPE_LENUM)
          if attribute.name in CONS.ALL_HEADERS
            "attribute.#{attribute.name}"
          else
            attribute.name

      langH2i = @_languageToIndex ptLanguageAttributes
      @productTypeId2HeaderIndex[productType.id] = langH2i
    langH2i

  missingHeaderForProductType: (productType) ->
    @toIndex()
    _.filter productType.attributes, (attribute) =>
      not @has(attribute.name) and not @productTypeAttributeToIndex(productType, attribute)

module.exports = Header
