_ = require('underscore')._
CONS = require '../lib/constants'

class Header
  constructor: (@rawHeader) ->

  # checks some basic rules for the header row
  validate: ->
    errors = []
    if @rawHeader.length isnt _.unique(@rawHeader).length
      errors.push "There are duplicate header entries!"

    missingHeaders = _.difference CONS.BASE_HEADERS, @rawHeader
    if _.size(missingHeaders) > 0
      for missingHeader in missingHeaders
        errors.push "Can't find necessary base header '#{missingHeader}'!"

    errors

  # "x,y,z"
  # toIndex:
  #   x: 0
  #   y: 1
  #   z: 2
  toIndex: (name) ->
    @h2i = _.object _.map @rawHeader, (head, index) -> [head, index] unless @h2i
    return @h2i[name] if name
    @h2i

  has: (name) ->
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
        parts = head.split CONS.DELIM_HEADER_LANGUAGE
        if _.size(parts) is 2
          if parts[0] is langAttribName
            lang = parts[1]
            # TODO: check language
            langH2i[langAttribName] or= {}
            langH2i[langAttribName][lang] = index

    langH2i

  # Stores the map between the id of product types and the language header index
  _productTypeLanguageIndexes: (productType) ->
    @productTypeId2HeaderIndex or= {}
    langH2i = @productTypeId2HeaderIndex[productType.id]
    unless langH2i
      ptLanguageAttributes = _.map productType.attributes, (attribute) -> attribute.name if attribute.type.name is CONS.ATTRIBUTE_TYPE_LTEXT
      langH2i = @_languageToIndex ptLanguageAttributes
      @productTypeId2HeaderIndex[productType.id] = langH2i
    langH2i

  missingHeaderForProductType: (productType) ->
    @toIndex()
    _.filter productType.attributes, (attribute) =>
      not @has(attribute.name) and not @productTypeAttributeToIndex(productType, attribute)

module.exports = Header