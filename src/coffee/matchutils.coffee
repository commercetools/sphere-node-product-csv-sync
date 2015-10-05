_ = require 'underscore'
GLOBALS = require './globals'
Helpers = require './helpers'

class MatchUtils

  @mapById: (product) ->
    Helpers.initMap(product.id, product)

  @mapBySlug: (product) ->
    Helpers.initMap(product.slug[GLOBALS.DEFAULT_LANGUAGE], product)

  @mapBySku: (product) ->
    map = {}
    product.variants or= []
    variants = [product.masterVariant].concat(product.variants)
    _.each variants, (v) ->
      map[v.sku] = product
    map

  @mapIdentifier: (matchBy) ->
    switch matchBy
      when 'id' then (entry) -> entry.product.id
      when 'slug' then (entry) -> entry.product.slug[GLOBALS.DEFAULT_LANGUAGE]
      when 'sku' then (entry) -> entry.product.masterVariant.sku
      else throw new Error("map function for #{matchBy} is not implemented")

  @mapMapper: (matchBy) ->
    switch matchBy
      when 'id' then MatchUtils.mapById
      when 'slug' then MatchUtils.mapBySlug
      when 'sku' then MatchUtils.mapBySku
      else throw new Error("identifier function for #{matchBy} is not implemented")

  @initMatcher: (matchBy, existingProducts) ->
    mapper = MatchUtils.mapMapper(matchBy)
    identifier = MatchUtils.mapIdentifier(matchBy)
    map = existingProducts.reduce((m, p) ->
      _.extend(m, mapper(p))
    , {})
    (entry) ->
      map[identifier(entry)]

module.exports = MatchUtils
