_ = require 'underscore'
GLOBALS = require './globals'
Helpers = require './helpers'

class MatchUtils

  # Create map of product.id -> product
  # @param {Object} product - Product
  @mapById: (product) ->
    Helpers.initMap(product.id, product)

  # Create map of product.slug -> product
  # @param {Object} product - Product
  @mapBySlug: (product) ->
    Helpers.initMap(product.slug[GLOBALS.DEFAULT_LANGUAGE], product)

  # Create map of product.[skus] -> product
  # @param {Object} product - Product
  @mapBySku: (product) ->
    [product.masterVariant].concat(product.variants || []).reduce((agg, v) ->
      _.extend(agg, Helpers.initMap(v.sku, product))
    , {})

  # Create map of product.[attrName] -> product
  # @param {String} attrName - name of the attribute
  # @param {Object} product - Product
  @mapByCustomAttribute: (attrName) -> (product) ->
    [product.masterVariant].concat(product.variants || []).reduce((agg, v) ->
      key = v.attributes.filter((a) -> a.name == attrName)[0].value
      _.extend(agg, Helpers.initMap(key, product))
    , {})

  # Map product identifier
  # @param {String} matchBy - attribute which will be used as an identifier
  @mapIdentifier: (matchBy) ->
    switch matchBy
      when 'id' then (entry) -> entry.product.id
      when 'slug' then (entry) -> entry.product.slug[GLOBALS.DEFAULT_LANGUAGE]
      when 'sku' then (entry) -> entry.product.masterVariant.sku
      else (entry) -> entry.product.masterVariant.attributes.
        filter((a) -> a.name == matchBy)[0].value

  # Map product identifier
  # @param {String} matchBy - attribute which will be used as an identifier
  @mapMapper: (matchBy) ->
    switch matchBy
      when 'id' then MatchUtils.mapById
      when 'slug' then MatchUtils.mapBySlug
      when 'sku' then MatchUtils.mapBySku
      else MatchUtils.mapByCustomAttribute(matchBy)

  # initialize match function which returns existing product based on shared
  # identifier
  # @param {String} matchBy - identifier attribute name
  # @param {Array} existingProducts - array of existing products
  @initMatcher: (matchBy, existingProducts) ->
    mapper = MatchUtils.mapMapper(matchBy)
    identifier = MatchUtils.mapIdentifier(matchBy)
    map = existingProducts.reduce((m, p) ->
      _.extend(m, mapper(p))
    , {})
    (entry) ->
      map[identifier(entry)]

module.exports = MatchUtils
