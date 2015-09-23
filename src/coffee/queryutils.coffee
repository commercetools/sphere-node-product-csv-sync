_ = require 'underscore'

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
    QueryUtils.formatAttributePredicate("slug", slugs)

  # Matches products by `sku` attribute
  # @param {object} service - SDK service object
  # @param {Array} products
  @matchBySku: (products) ->
    skus = _.flatten(products.map((p) ->
      [p.product.masterVariant.sku].concat(p.product.variants.map((v) ->
        v.sku)))).filter(x ->
          !!x)
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
          QueryUtils.valueOf(v.attributes, attribute))))).filter(x ->
            !!x)
      predicate = QueryUtils.formatAttributePredicate(attribute, values)
      QueryUtils.applyPredicateToVariants(predicate)

  # Withdraw particular attribute value out of attributes collection
  # @param {Array} attributes - attributes collection
  # @param {String} name - name of the attribute
  # @return {Any} attribute value if found
  @valueOf: (attributes, name) ->
    attrib = _.find(attributes || [], (attribute) ->
      attribute.name is name)
    attrib?.value

  @formatAttributePredicate: (name, items) ->
    "#{attribute} in (\"#{items.join('", "')}\")"

  @applyPredicateToVariants: (predicate) ->
    "masterVariant(#{predicate}) or variants(#{predicate})"

module.exports = QueryUtils
