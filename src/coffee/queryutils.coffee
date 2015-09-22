_ = require 'underscore'

class QueryUtils

  @mapMatchFunction: (matchBy) ->
    switch matchBy
      when 'id' then QueryUtils.matchById
      when 'sku' then QueryUtils.matchBySku
      when 'slug' then QueryUtils.matchBySlug
      else QueryUtils.matchByCustomAttribute(matchBy)

  # Matches products by `id` attribute
  # @param {object} service - SDK service object
  # @param {Array} products
  @matchById: (products) ->
    ids = products.map((p) -> "\"#{p.product.id}\"")
    filterInput = "id:in (#{ids.join(',')})"

  # Matches products by `sku` attribute
  # @param {object} service - SDK service object
  # @param {Array} products
  @matchBySku: (products) ->
    skus = _.flatten(products.map((p) ->
      [p.product.masterVariant.sku].concat(p.product.variants.map((v) ->
        v.sku))))
    predicate = "sku in (\"#{skus.join('", "')}\")"
    filterInput = "masterVariant(#{predicate}) or variants(#{predicate})"

  # Matches products by `slug` attribute
  # @param {object} service - SDK service object
  # @param {Array} products
  @matchBySlug: (products) ->
    slugs = products.map((p) ->
      p.product.slug[GLOBALS.DEFAULT_LANGUAGE])
    filterInput = "slug in (\"#{slugs.join('", "')}\")"

  # Matches products by custom attribute
  # @param {object} service - SDK service object
  # @param {Array} products
  @matchByCustomAttribute: (attribute) ->
    (products) ->
      attributes = _.flatten(products.map((p) ->
        [
          QueryUtils.valueOf(p.product.masterVariant.attributes, attribute)
        ].concat(p.product.variants.map((v) ->
          QueryUtils.valueOf(v.attributes, attribute)))))
      predicate = "#{attribute} in (\"#{attributes.join('", "')}\")"
      filterInput = "masterVariant(#{predicate}) or variants(#{predicate})"

  @valueOf: (attributes, name) ->
    attrib = _.find(attributes || [], (attribute) ->
      attribute.name is name)
    attrib?.value

module.exports = QueryUtils
