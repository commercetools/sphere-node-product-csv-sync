_ = require 'underscore'
GLOBALS = require './globals'

class Helpers

  @exists: (x) -> !!x

class QueryUtils

  @mapMatchFunction: (matchBy) ->
    switch matchBy
      when 'id' then QueryUtils.matchById
      when 'slug' then QueryUtils.matchBySlug
      when 'sku' then QueryUtils.matchBySku
      else QueryUtils.matchByCustomAttribute(matchBy)

  # Matches products by `id` attribute
  # @param {object} service - SDK service object
  # @param {Array} products
  @matchById: (products) ->
    ids = products.map((p) -> p.product.id)
    QueryUtils.formatAttributePredicate("id", ids)

  # Matches products by `slug` attribute
  # @param {object} service - SDK service object
  # @param {Array} products
  @matchBySlug: (products) ->
    slugs = products.map((p) ->
      p.product.slug[GLOBALS.DEFAULT_LANGUAGE])
    "slug(#{QueryUtils.formatAttributePredicate(GLOBALS.DEFAULT_LANGUAGE, slugs)})"

  # Matches products by `sku` attribute
  # @param {object} service - SDK service object
  # @param {Array} products
  @matchBySku: (products) ->
    skus = products.map((p) ->
      p.product.masterVariant.sku
    ).filter(Helpers.exists)
    predicate = QueryUtils.formatAttributePredicate("sku", skus)
    QueryUtils.applyPredicateToVariants(predicate)

  # Matches products by custom attribute
  # @param {object} service - SDK service object
  # @param {Array} products
  @matchByCustomAttribute: (attribute) ->
    (products) ->
      values = _.flatten(products.map((p) ->
        [
          QueryUtils.valueOf(p.product.masterVariant.attributes, attribute)
        ].concat(p.product.variants.map((v) ->
          QueryUtils.valueOf(v.attributes, attribute)))))
          .filter(Helpers.exists)
      predicate = QueryUtils.formatCustomAttributePredicate(attribute, values)
      QueryUtils.applyPredicateToVariants(predicate)

  # Withdraw particular attribute value out of attributes collection
  # @param {Array} attributes - attributes collection
  # @param {String} name - name of the attribute
  # @return {Any} attribute value if found
  @valueOf: (attributes, name) ->
    attrib = _.find(attributes, (attribute) ->
      attribute.name is name)
    attrib?.value

  @formatAttributePredicate: (name, items) ->
    escapedItems = items.map((item) -> item.replace /"/g, '%22')
    "#{name} in (\"#{escapedItems.join('", "')}\")"

  @formatCustomAttributePredicate: (name, items) ->
    "attributes(name=\"#{name}\" and value in (\"#{items.join('", "')}\"))"

  @applyPredicateToVariants: (predicate) ->
    "masterVariant(#{predicate}) or variants(#{predicate})"

module.exports = QueryUtils
