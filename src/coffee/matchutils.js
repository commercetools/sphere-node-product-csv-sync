/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const GLOBALS = require('./globals');
const Helpers = require('./helpers');

class MatchUtils {

  // Create map of product.id -> product
  // @param {Object} product - Product
  static mapById(product) {
    return Helpers.initMap(product.id, product);
  }

  // Create map of product.slug -> product
  // @param {Object} product - Product
  static mapBySlug(product) {
    return Helpers.initMap(product.slug[GLOBALS.DEFAULT_LANGUAGE], product);
  }

  // Create map of product.[skus] -> product
  // @param {Object} product - Product
  static mapBySku(product) {
    return [product.masterVariant].concat(product.variants || []).reduce((agg, v) => _.extend(agg, Helpers.initMap(v.sku, product))
    , {});
  }

  // Create map of product.[attrName] -> product
  // @param {String} attrName - name of the attribute
  // @param {Object} product - Product
  static mapByCustomAttribute(attrName) { return product =>
    [product.masterVariant].concat(product.variants || []).reduce(function(agg, v) {
      const key = v.attributes.filter(a => a.name === attrName)[0].value;
      return _.extend(agg, Helpers.initMap(key, product));
    }
    , {})
  ; }

  // Map product identifier
  // @param {String} matchBy - attribute which will be used as an identifier
  static mapIdentifier(matchBy) {
    switch (matchBy) {
      case 'id': return entry => entry.product.id;
      case 'slug': return entry => entry.product.slug[GLOBALS.DEFAULT_LANGUAGE];
      case 'sku': return entry => entry.product.masterVariant.sku;
      default: return entry => entry.product.masterVariant.attributes.
        filter(a => a.name === matchBy)[0].value ;
    }
  }

  // Map product identifier
  // @param {String} matchBy - attribute which will be used as an identifier
  static mapMapper(matchBy) {
    switch (matchBy) {
      case 'id': return MatchUtils.mapById;
      case 'slug': return MatchUtils.mapBySlug;
      case 'sku': return MatchUtils.mapBySku;
      default: return MatchUtils.mapByCustomAttribute(matchBy);
    }
  }

  // initialize match function which returns existing product based on shared
  // identifier
  // @param {String} matchBy - identifier attribute name
  // @param {Array} existingProducts - array of existing products
  static initMatcher(matchBy, existingProducts) {
    const mapper = MatchUtils.mapMapper(matchBy);
    const identifier = MatchUtils.mapIdentifier(matchBy);
    const map = existingProducts.reduce((m, p) => _.extend(m, mapper(p))
    , {});
    return entry => map[identifier(entry)];
  }
}

module.exports = MatchUtils;
