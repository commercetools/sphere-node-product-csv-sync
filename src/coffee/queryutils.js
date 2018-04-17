/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const GLOBALS = require('./globals');

class Helpers {

  static exists(x) { return !!x; }
}

class QueryUtils {

  static mapMatchFunction(matchBy) {
    switch (matchBy) {
      case 'id': return QueryUtils.matchById;
      case 'slug': return QueryUtils.matchBySlug;
      case 'sku': return QueryUtils.matchBySku;
      default: return QueryUtils.matchByCustomAttribute(matchBy);
    }
  }

  // Matches products by `id` attribute
  // @param {object} service - SDK service object
  // @param {Array} products
  static matchById(products) {
    const ids = products.map(p => p.product.id);
    return QueryUtils.formatAttributePredicate("id", ids);
  }

  // Matches products by `slug` attribute
  // @param {object} service - SDK service object
  // @param {Array} products
  static matchBySlug(products) {
    const slugs = products.map(p => p.product.slug[GLOBALS.DEFAULT_LANGUAGE]);
    return `slug(${QueryUtils.formatAttributePredicate(GLOBALS.DEFAULT_LANGUAGE, slugs)})`;
  }

  // Matches products by `sku` attribute
  // @param {object} service - SDK service object
  // @param {Array} products
  static matchBySku(products) {
    const skus = products.map(p => p.product.masterVariant.sku).filter(Helpers.exists);
    const predicate = QueryUtils.formatAttributePredicate("sku", skus);
    return QueryUtils.applyPredicateToVariants(predicate);
  }

  // Matches products by custom attribute
  // @param {object} service - SDK service object
  // @param {Array} products
  static matchByCustomAttribute(attribute) {
    return function(products) {
      const values = _.flatten(products.map(p =>
        [
          QueryUtils.valueOf(p.product.masterVariant.attributes, attribute)
        ].concat(p.product.variants.map(v => QueryUtils.valueOf(v.attributes, attribute)))))
          .filter(Helpers.exists);
      const predicate = QueryUtils.formatCustomAttributePredicate(attribute, values);
      return QueryUtils.applyPredicateToVariants(predicate);
    };
  }

  // Withdraw particular attribute value out of attributes collection
  // @param {Array} attributes - attributes collection
  // @param {String} name - name of the attribute
  // @return {Any} attribute value if found
  static valueOf(attributes, name) {
    const attrib = _.find(attributes, attribute => attribute.name === name);
    return (attrib != null ? attrib.value : undefined);
  }

  static formatAttributePredicate(name, items) {
    return `${name} in (${this.escapeItems(items)})`;
  }

  static formatCustomAttributePredicate(name, items) {
    return `attributes(name=\"${name}\" and value in (${this.escapeItems(items)}))`;
  }

  static applyPredicateToVariants(predicate) {
    return `masterVariant(${predicate}) or variants(${predicate})`;
  }

  static escapeItems(items) {
    if (items.length === 0) {
      return '""';
    } else {
      return items.map(item => JSON.stringify(item)).join(", ");
    }
  }
}

module.exports = QueryUtils;
