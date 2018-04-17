/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const CONS = require('../lib/constants');
const GLOBALS = require('../lib/globals');

// TODO:
// - JSDoc
// - put it under utils
class Header {

  constructor(rawHeader) {
    this.rawHeader = rawHeader;
  }

  // checks some basic rules for the header row
  validate() {
    const errors = [];
    if (this.rawHeader.length !== _.unique(this.rawHeader).length) {
      errors.push("There are duplicate header entries!");
    }

    const missingHeaders = _.difference([CONS.HEADER_PRODUCT_TYPE], this.rawHeader);
    if (_.size(missingHeaders) > 0) {
      for (let missingHeader of Array.from(missingHeaders)) {
        errors.push(`Can't find necessary base header '${missingHeader}'!`);
      }
    }

    if (!_.contains(this.rawHeader, CONS.HEADER_VARIANT_ID) && !_.contains(this.rawHeader, CONS.HEADER_SKU)) {
      errors.push(`You need either the column '${CONS.HEADER_VARIANT_ID}' or '${CONS.HEADER_SKU}' to identify your variants!`);
    }

    return errors;
  }

  // "x,y,z"
  // toIndex:
  //   x: 0
  //   y: 1
  //   z: 2
  toIndex(name) {
    this.h2i = _.object(_.map(this.rawHeader, function(head, index) { if (!this.h2i) { return [head, index]; } }));
    if (name) { return this.h2i[name]; }
    return this.h2i;
  }

  has(name) {
    if (this.h2i == null) { this.toIndex(); }
    return _.has(this.h2i, name);
  }

  toLanguageIndex(name) {
    if (!this.langH2i) { this.langH2i = this._languageToIndex(CONS.BASE_LOCALIZED_HEADERS); }
    if (name) { return this.langH2i[name]; }
    return this.langH2i;
  }

  hasLanguageForBaseAttribute(name) {
    return _.has(this.langH2i, name);
  }

  hasLanguageForCustomAttribute(name) {
    const foo = _.find(this.productTypeId2HeaderIndex, productTypeLangH2i => _.has(productTypeLangH2i, name));
    return (foo != null);
  }

  // "a,x.de,y,x.it,z"
  // productTypeAttributeToIndex for 'x'
  //   de: 1
  //   it: 3
  productTypeAttributeToIndex(productType, attribute) {
    return this._productTypeLanguageIndexes(productType)[attribute.name];
  }

  // "x,a1.de,foo,a1.it"
  // _languageToIndex =
  //   a1:
  //     de: 1
  //     it: 3
  _languageToIndex(localizedAttributes) {
    const langH2i = {};
    for (let langAttribName of Array.from(localizedAttributes)) {
      for (let index = 0; index < this.rawHeader.length; index++) {
        const head = this.rawHeader[index];
        const parts = head.split(GLOBALS.DELIM_HEADER_LANGUAGE);
        if (_.size(parts) === 2) {
          if (parts[0] === langAttribName) {
            const lang = parts[1];
            // TODO: check language
            if (!langH2i[langAttribName]) { langH2i[langAttribName] = {}; }
            langH2i[langAttribName][lang] = index;
          }
        }
      }
    }

    return langH2i;
  }

  // Stores the map between the id of product types and the language header index
  // Lenum and Set of Lenum are now first class localised citizens
  _productTypeLanguageIndexes(productType) {
    if (!this.productTypeId2HeaderIndex) { this.productTypeId2HeaderIndex = {}; }
    let langH2i = this.productTypeId2HeaderIndex[productType.id];
    if (!langH2i) {
      const ptLanguageAttributes = _.map(productType.attributes, function(attribute) {
        if ((attribute.type.name === CONS.ATTRIBUTE_TYPE_LTEXT) ||
        ((attribute.type.name === CONS.ATTRIBUTE_TYPE_SET) && ((attribute.type.elementType != null ? attribute.type.elementType.name : undefined) === CONS.ATTRIBUTE_TYPE_LTEXT)) ||
        (attribute.type.name === CONS.ATTRIBUTE_TYPE_LENUM) ||
        ((attribute.type.name === CONS.ATTRIBUTE_TYPE_SET) && ((attribute.type.elementType != null ? attribute.type.elementType.name : undefined) === CONS.ATTRIBUTE_TYPE_LENUM))) {
          return attribute.name;
        }
      });
      langH2i = this._languageToIndex(ptLanguageAttributes);
      this.productTypeId2HeaderIndex[productType.id] = langH2i;
    }
    return langH2i;
  }

  missingHeaderForProductType(productType) {
    this.toIndex();
    return _.filter(productType.attributes, attribute => {
      return !this.has(attribute.name) && !this.productTypeAttributeToIndex(productType, attribute);
    });
  }
}

module.exports = Header;
