/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
_.mixin(require('underscore.string').exports());
const CONS = require('./constants');
const GLOBALS = require('./globals');

// TODO:
// - JSDoc
// - no services!!!
// - utils only
class Mapping {

  constructor(options) {
    if (options == null) { options = {}; }
    this.types = options.types;
    this.customerGroups = options.customerGroups;
    this.categories = options.categories;
    this.taxes = options.taxes;
    this.channels = options.channels;
    this.continueOnProblems = options.continueOnProblems;
    this.errors = [];
  }

  mapProduct(raw, productType) {
    if (!productType) { productType = raw.master[this.header.toIndex(CONS.HEADER_PRODUCT_TYPE)]; }
    const rowIndex = raw.startRow;

    const product = this.mapBaseProduct(raw.master, productType, rowIndex);
    product.masterVariant = this.mapVariant(raw.master, 1, productType, rowIndex, product);
    _.each(raw.variants, (entry, index) => {
      return product.variants.push(this.mapVariant(entry.variant, index + 2, productType, entry.rowIndex, product));
    });

    const data = {
      product,
      rowIndex: raw.startRow,
      header: this.header,
      publish: raw.publish
    };
    return data;
  }

  mapBaseProduct(rawMaster, productType, rowIndex) {
    const product = {
      productType: {
        typeId: 'product-type',
        id: productType.id
      },
      masterVariant: {},
      variants: []
    };

    if (this.header.has(CONS.HEADER_ID)) {
      product.id = rawMaster[this.header.toIndex(CONS.HEADER_ID)];
    }

    if (this.header.has(CONS.HEADER_KEY)) {
      product.key = rawMaster[this.header.toIndex(CONS.HEADER_KEY)];
    }

    product.categories = this.mapCategories(rawMaster, rowIndex);
    const tax = this.mapTaxCategory(rawMaster, rowIndex);
    if (tax) { product.taxCategory = tax; }
    product.categoryOrderHints = this.mapCategoryOrderHints(rawMaster, rowIndex);

    for (let attribName of Array.from(CONS.BASE_LOCALIZED_HEADERS)) {
      var val;
      if (attribName === CONS.HEADER_SEARCH_KEYWORDS) {
        val = this.mapSearchKeywords(rawMaster, attribName,  this.header.toLanguageIndex());
      } else {
        val = this.mapLocalizedAttrib(rawMaster, attribName, this.header.toLanguageIndex());
      }
      if (val) { product[attribName] = val; }
    }

    if (!product.slug) {
      product.slug = {};
      if ((product.name != null) && (product.name[GLOBALS.DEFAULT_LANGUAGE] != null)) {
        product.slug[GLOBALS.DEFAULT_LANGUAGE] = this.ensureValidSlug(_.slugify(product.name[GLOBALS.DEFAULT_LANGUAGE], rowIndex));
      }
    }
    return product;
  }

  ensureValidSlug(slug, rowIndex, appendix) {
    if (appendix == null) { appendix = ''; }
    if (!_.isString(slug) || !(slug.length > 2)) {
      this.errors.push(`[row ${rowIndex}:${CONS.HEADER_SLUG}] Can't generate valid slug out of '${slug}'!`);
      return;
    }
    if (!this.slugs) { this.slugs = []; }
    const currentSlug = `${slug}${appendix}`;
    if (!_.contains(this.slugs, currentSlug)) {
      this.slugs.push(currentSlug);
      return currentSlug;
    }
    return this.ensureValidSlug(slug, rowIndex, Math.floor((Math.random() * 89999) + 10001)); // five digets
  }

  hasValidValueForHeader(row, headerName) {
    if (!this.header.has(headerName)) { return false; }
    return this.isValidValue(row[this.header.toIndex(headerName)]);
  }

  isValidValue(rawValue) {
    return _.isString(rawValue) && (rawValue.length > 0);
  }

  mapCategories(rawMaster, rowIndex) {
    const categories = [];
    if (!this.hasValidValueForHeader(rawMaster, CONS.HEADER_CATEGORIES)) { return categories; }
    const rawCategories = rawMaster[this.header.toIndex(CONS.HEADER_CATEGORIES)].split(GLOBALS.DELIM_MULTI_VALUE);
    for (let rawCategory of Array.from(rawCategories)) {
      var msg;
      const cat =
        {typeId: 'category'};
      if (_.has(this.categories.externalId2id, rawCategory)) {
        cat.id = this.categories.externalId2id[rawCategory];
      } else if (_.has(this.categories.fqName2id, rawCategory)) {
        cat.id = this.categories.fqName2id[rawCategory];
      } else if (_.has(this.categories.name2id, rawCategory)) {
        if (_.contains(this.categories.duplicateNames, rawCategory)) {
          msg =  `[row ${rowIndex}:${CONS.HEADER_CATEGORIES}] The category '${rawCategory}' is not unqiue!`;
          if (this.continueOnProblems) {
            console.warn(msg);
          } else {
            this.errors.push(msg);
          }
        } else {
          cat.id = this.categories.name2id[rawCategory];
        }
      }

      if (cat.id) {
        categories.push(cat);

      } else {
        msg = `[row ${rowIndex}:${CONS.HEADER_CATEGORIES}] Can not find category for '${rawCategory}'!`;
        if (this.continueOnProblems) {
          console.warn(msg);
        } else {
          this.errors.push(msg);
        }
      }
    }

    return categories;
  }

  // parses the categoryOrderHints column for a given row
  mapCategoryOrderHints(rawMaster, rowIndex) {
    const catOrderHints = {};
    // check if there actually is something to parse in the column
    if (!this.hasValidValueForHeader(rawMaster, CONS.HEADER_CATEGORY_ORDER_HINTS)) { return catOrderHints; }
    // parse the value to get a list of all catOrderHints
    const rawCatOrderHints = rawMaster[this.header.toIndex(CONS.HEADER_CATEGORY_ORDER_HINTS)].split(GLOBALS.DELIM_MULTI_VALUE);
    _.each(rawCatOrderHints, rawCatOrderHint => {
      // extract the category id and the order hint from the raw value
      let msg;
      const [rawCatId, rawOrderHint] = Array.from(rawCatOrderHint.split(':'));
      const orderHint = parseFloat(rawOrderHint);
      // check if the product is actually assigned to the category
      const catId =
        (() => {
        if (_.has(this.categories.id2fqName, rawCatId)) {
          return rawCatId;
        } else if (_.has(this.categories.externalId2id, rawCatId)) {
          return this.categories.externalId2id[rawCatId];
        // in case the category was provided as the category name
        // check if the product is actually assigend to the category
        } else if (_.has(this.categories.name2id, rawCatId)) {
          // get the actual category id instead of the category name
          return this.categories.name2id[rawCatId];
        // in case the category was provided using the category slug
        } else if (_.contains(this.categories.id2slug, rawCatId)) {
          // get the actual category id instead of the category name
          return _.findKey(this.categories.id2slug, slug => slug === rawCatId);
        } else {
          msg = `[row ${rowIndex}:${CONS.HEADER_CATEGORY_ORDER_HINTS}] Can not find category for ID '${rawCatId}'!`;
          if (this.continueOnProblems) {
            console.warn(msg);
          } else {
            this.errors.push(msg);
          }
          return null;
        }
      })();

      if (orderHint === NaN) {
        msg = `[row ${rowIndex}:${CONS.HEADER_CATEGORY_ORDER_HINTS}] Order hint has to be a valid number!`;
        if (this.continueOnProblems) {
          return console.warn(msg);
        } else {
          return this.errors.push(msg);
        }
      } else if (!((orderHint > 0) && (orderHint < 1))) {
        msg = `[row ${rowIndex}:${CONS.HEADER_CATEGORY_ORDER_HINTS}] Order hint has to be < 1 and > 0 but was '${orderHint}'!`;
        if (this.continueOnProblems) {
          return console.warn(msg);
        } else {
          return this.errors.push(msg);
        }
      } else {
        if (catId) {
          // orderHint and catId are ensured to be valid
          return catOrderHints[catId] = orderHint.toString();
        }
      }
    });

    return catOrderHints;
  }


  mapTaxCategory(rawMaster, rowIndex) {
    let tax;
    if (!this.hasValidValueForHeader(rawMaster, CONS.HEADER_TAX)) { return; }
    const rawTax = rawMaster[this.header.toIndex(CONS.HEADER_TAX)];
    if (_.contains(this.taxes.duplicateNames, rawTax)) {
      this.errors.push(`[row ${rowIndex}:${CONS.HEADER_TAX}] The tax category '${rawTax}' is not unqiue!`);
      return;
    }
    if (!_.has(this.taxes.name2id, rawTax)) {
      this.errors.push(`[row ${rowIndex}:${CONS.HEADER_TAX}] The tax category '${rawTax}' is unknown!`);
      return;
    }

    return tax = {
      typeId: 'tax-category',
      id: this.taxes.name2id[rawTax]
    };
  }

  mapVariant(rawVariant, variantId, productType, rowIndex, product) {
    if ((variantId > 2) && this.header.has(CONS.HEADER_VARIANT_ID)) {
      const vId = this.mapInteger(rawVariant[this.header.toIndex(CONS.HEADER_VARIANT_ID)], CONS.HEADER_VARIANT_ID, rowIndex);
      if ((vId != null) && !_.isNaN(vId)) {
        variantId = vId;
      } else {
        // we have no valid variant id - mapInteger already mentioned this as error
        return;
      }
    }

    const variant = {
      id: variantId,
      attributes: []
    };

    if (this.header.has(CONS.HEADER_VARIANT_KEY)) {
      variant.key = rawVariant[this.header.toIndex(CONS.HEADER_VARIANT_KEY)];
    }

    if (this.header.has(CONS.HEADER_SKU)) { variant.sku = rawVariant[this.header.toIndex(CONS.HEADER_SKU)]; }

    const languageHeader2Index = this.header._productTypeLanguageIndexes(productType);
    if (productType.attributes) {
      for (var attribute of Array.from(productType.attributes)) {
        const attrib = (attribute.attributeConstraint === CONS.ATTRIBUTE_CONSTRAINT_SAME_FOR_ALL) && (variantId > 1) ?
          _.find(product.masterVariant.attributes, a => a.name === attribute.name)
        :
          this.mapAttribute(rawVariant, attribute, languageHeader2Index, rowIndex);
        if (attrib) { variant.attributes.push(attrib); }
      }
    }

    variant.prices = this.mapPrices(rawVariant[this.header.toIndex(CONS.HEADER_PRICES)], rowIndex);
    variant.images = this.mapImages(rawVariant, variantId, rowIndex);

    return variant;
  }

  mapAttribute(rawVariant, attribute, languageHeader2Index, rowIndex) {
    const value = this.mapValue(rawVariant, attribute, languageHeader2Index, rowIndex);
    if (_.isUndefined(value) || (_.isObject(value) && _.isEmpty(value)) || (_.isString(value) && _.isEmpty(value))) { return undefined; }
    attribute = {
      name: attribute.name,
      value
    };
    return attribute;
  }

  mapValue(rawVariant, attribute, languageHeader2Index, rowIndex) {
    switch (attribute.type.name) {
      case CONS.ATTRIBUTE_TYPE_SET: return this.mapSetAttribute(rawVariant, attribute.name, attribute.type.elementType, languageHeader2Index, rowIndex);
      case CONS.ATTRIBUTE_TYPE_LTEXT: return this.mapLocalizedAttrib(rawVariant, attribute.name, languageHeader2Index);
      case CONS.ATTRIBUTE_TYPE_NUMBER: return this.mapNumber(rawVariant[this.header.toIndex(attribute.name)], attribute.name, rowIndex);
      case CONS.ATTRIBUTE_TYPE_BOOLEAN: return this.mapBoolean(rawVariant[this.header.toIndex(attribute.name)], attribute.name, rowIndex);
      case CONS.ATTRIBUTE_TYPE_MONEY: return this.mapMoney(rawVariant[this.header.toIndex(attribute.name)], attribute.name, rowIndex);
      case CONS.ATTRIBUTE_TYPE_REFERENCE: return this.mapReference(rawVariant[this.header.toIndex(attribute.name)], attribute, rowIndex);
      default: return rawVariant[this.header.toIndex(attribute.name)]; // works for text, enum and lenum
    }
  }

  mapSetAttribute(rawVariant, attributeName, elementType, languageHeader2Index, rowIndex) {
    if (elementType.name === CONS.ATTRIBUTE_TYPE_LTEXT) {
      const multiValObj = this.mapLocalizedAttrib(rawVariant, attributeName, languageHeader2Index);
      const value = [];
      _.each(multiValObj, (raw, lang) => {
        if (this.isValidValue(raw)) {
          const languageVals = raw.split(GLOBALS.DELIM_MULTI_VALUE);
          return _.each(languageVals, function(v, index) {
            const localized = {};
            localized[lang] = v;
            return value[index] = _.extend((value[index] || {}), localized);
          });
        }
      });
      return value;
    } else {
      const raw = rawVariant[this.header.toIndex(attributeName)];
      if (this.isValidValue(raw)) {
        const rawValues = raw.split(GLOBALS.DELIM_MULTI_VALUE);
        return _.map(rawValues, rawValue => {
          switch (elementType.name) {
            case CONS.ATTRIBUTE_TYPE_MONEY:
              return this.mapMoney(rawValue, attributeName, rowIndex);
            case CONS.ATTRIBUTE_TYPE_NUMBER:
              return this.mapNumber(rawValue, attributeName, rowIndex);
            default:
              return rawValue;
          }
        });
      }
    }
  }

  mapPrices(raw, rowIndex) {
    const prices = [];
    if (!this.isValidValue(raw)) { return prices; }
    const rawPrices = raw.split(GLOBALS.DELIM_MULTI_VALUE);
    for (let rawPrice of Array.from(rawPrices)) {
      const matchedPrice = CONS.REGEX_PRICE.exec(rawPrice);
      if (!matchedPrice) {
        this.errors.push(`[row ${rowIndex}:${CONS.HEADER_PRICES}] Can not parse price '${rawPrice}'!`);
        continue;
      }

      const country = matchedPrice[2];
      const currencyCode = matchedPrice[3];
      const centAmount = matchedPrice[4];
      const customerGroupName = matchedPrice[8];
      const channelKey = matchedPrice[10];
      const validFrom = matchedPrice[12];
      const validUntil = matchedPrice[14];
      const price =
        {value: this.mapMoney(`${currencyCode} ${centAmount}`, CONS.HEADER_PRICES, rowIndex)};
      if (validFrom) { price.validFrom = validFrom; }
      if (validUntil) { price.validUntil = validUntil; }
      if (country) { price.country = country; }

      if (customerGroupName) {
        if (!_.has(this.customerGroups.name2id, customerGroupName)) {
          this.errors.push(`[row ${rowIndex}:${CONS.HEADER_PRICES}] Can not find customer group '${customerGroupName}'!`);
          return [];
        }
        price.customerGroup = {
          typeId: 'customer-group',
          id: this.customerGroups.name2id[customerGroupName]
        };
      }
      if (channelKey) {
        if (!_.has(this.channels.key2id, channelKey)) {
          this.errors.push(`[row ${rowIndex}:${CONS.HEADER_PRICES}] Can not find channel with key '${channelKey}'!`);
          return [];
        }
        price.channel = {
          typeId: 'channel',
          id: this.channels.key2id[channelKey]
        };
      }

      prices.push(price);
    }

    return prices;
  }

  // EUR 300
  // USD 999
  mapMoney(rawMoney, attribName, rowIndex) {
    let money;
    if (!this.isValidValue(rawMoney)) { return; }
    const matchedMoney = CONS.REGEX_MONEY.exec(rawMoney);
    if (!matchedMoney) {
      this.errors.push(`[row ${rowIndex}:${attribName}] Can not parse money '${rawMoney}'!`);
      return;
    }
    // TODO: check for correct currencyCode

    return money = {
      currencyCode: matchedMoney[1],
      centAmount: parseInt(matchedMoney[2])
    };
  }

  mapReference(rawReference, attribute, rowIndex) {
    let ref;
    if (!rawReference) { return undefined; }
    return ref = {
      id: rawReference,
      typeId: attribute.type.referenceTypeId
    };
  }

  mapInteger(rawNumber, attribName, rowIndex) {
    return parseInt(this.mapNumber(rawNumber, attribName, rowIndex, CONS.REGEX_INTEGER));
  }

  mapNumber(rawNumber, attribName, rowIndex, regEx) {
    if (regEx == null) { regEx = CONS.REGEX_FLOAT; }
    if (!this.isValidValue(rawNumber)) { return; }
    const matchedNumber = regEx.exec(rawNumber);
    if (!matchedNumber) {
      this.errors.push(`[row ${rowIndex}:${attribName}] The number '${rawNumber}' isn't valid!`);
      return;
    }
    return parseFloat(matchedNumber[0]);
  }

  mapBoolean(rawBoolean, attribName, rowIndex) {
    if (_.isUndefined(rawBoolean) || (_.isString(rawBoolean) && _.isEmpty(rawBoolean))) {
      return;
    }
    const errorMsg = `[row ${rowIndex}:${attribName}] The value '${rawBoolean}' isn't a valid boolean!`;
    try {
      const b = JSON.parse(rawBoolean.toLowerCase());
      if (_.isBoolean(b) || (b === 0) || (b === 1)) {
        return Boolean(b);
      } else {
        this.errors.push(errorMsg);
        return;
      }
    } catch (error) {
      return this.errors.push(errorMsg);
    }
  }

  // "a.en,a.de,a.it"
  // "hi,Hallo,ciao"
  // values:
  //   de: 'Hallo'
  //   en: 'hi'
  //   it: 'ciao'
  mapLocalizedAttrib(row, attribName, langH2i) {
    const values = {};
    if (_.has(langH2i, attribName)) {
      _.each(langH2i[attribName], function(index, language) {
        const val = row[index];
        if (val) { return values[language] = val; }
      });
    }
    // fall back to non localized column if language columns could not be found
    if (_.size(values) === 0) {
      if (!this.header.has(attribName)) { return; }
      const val = row[this.header.toIndex(attribName)];
      if (val) { values[GLOBALS.DEFAULT_LANGUAGE] = val; }
    }

    if (_.isEmpty(values)) { return; }
    return values;
  }

  // "a.en,a.de,a.it"
  // "hi,Hallo,ciao"
  // values:
  //   de: 'Hallo'
  //   en: 'hi'
  //   it: 'ciao'
  mapSearchKeywords(row, attribName, langH2i) {
    const values = {};
    if (_.has(langH2i, attribName)) {
      _.each(langH2i[attribName], function(index, language) {
        const val = row[index];
        if (!_.isString(val) || (val === "")) {
          return;
        }

        const singleValues = val.split(GLOBALS.DELIM_MULTI_VALUE);
        const texts = [];
        _.each(singleValues, (v, index) => texts.push({ text: v}));
        return values[language] = texts;
      });
    }
    // fall back to non localized column if language columns could not be found
    if (_.size(values) === 0) {
      if (!this.header.has(attribName)) { return; }
      const val = row[this.header.toIndex(attribName)];
      if (val) { values[GLOBALS.DEFAULT_LANGUAGE].text = val; }
    }

    if (_.isEmpty(values)) { return; }
    return values;
  }



  mapImages(rawVariant, variantId, rowIndex) {
    const images = [];
    if (!this.hasValidValueForHeader(rawVariant, CONS.HEADER_IMAGES)) { return images; }
    const rawImages = rawVariant[this.header.toIndex(CONS.HEADER_IMAGES)].split(GLOBALS.DELIM_MULTI_VALUE);

    for (let rawImage of Array.from(rawImages)) {
      const image = {
        url: rawImage,
        // TODO: get dimensions from CSV - format idea: 200x400;90x90
        dimensions: {
          w: 0,
          h: 0
        }
      };
        //  label: 'TODO'
      images.push(image);
    }

    return images;
  }
}


module.exports = Mapping;
