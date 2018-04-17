/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Promise = require('bluebird');
const _ = require('underscore');
const archiver = require('archiver');
_.mixin(require('underscore-mixins'));
const iconv = require('iconv-lite');
const {Import} = require('../../lib/main');
const Config = require('../../config');
const TestHelpers = require('./testhelpers');
const cuid = require('cuid');
const path = require('path');
const tmp = require('tmp');
const fs = Promise.promisifyAll(require('fs'));
// will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup();

const TEXT_ATTRIBUTE_NONE = 'attr-text-n';
const LTEXT_ATTRIBUTE_COMBINATION_UNIQUE = 'attr-ltext-cu';
const NUMBER_ATTRIBUTE_COMBINATION_UNIQUE = 'attr-number-cu';
const ENUM_ATTRIBUTE_SAME_FOR_ALL = 'attr-enum-sfa';
const SET_ATTRIBUTE_TEXT_UNIQUE = 'attr-set-text-u';
const SET_ATTRIBUTE_ENUM_NONE = 'attr-set-enum-n';
const SET_ATTRIBUTE_LENUM_SAME_FOR_ALL = 'attr-set-lenum-sfa';
const REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE = 'attr-ref-product-type-n';

const createImporter = function() {
  const im = new Import(Config);
  im.matchBy = 'sku';
  im.allowRemovalOfVariants = true;
  im.suppressMissingHeaderWarning = true;
  return im;
};

const CHANNEL_KEY = 'retailerA';

describe('Import integration test', function() {

  beforeEach(function(done) {
    jasmine.getEnv().defaultTimeoutInterval = 90000; // 90 sec
    this.importer = createImporter();
    this.client = this.importer.client;

    this.productType = TestHelpers.mockProductType();

    return TestHelpers.setupProductType(this.client, this.productType)
    .then(result => {
      this.productType = result;
      return this.client.channels.ensure(CHANNEL_KEY, 'InventorySupply');
  }).then(() => done())
    .catch(err => done(_.prettify(err.body)))
    .done();
  }
  , 120000); // 2min

  return describe('#import', function() {

    beforeEach(function() {
      this.newProductName = TestHelpers.uniqueId('name-');
      this.newProductSlug = TestHelpers.uniqueId('slug-');
      this.newProductSku = TestHelpers.uniqueId('sku-');
      return this.newProductSku += '"foo"';
    });

    it('should import a simple product', function(done) {
      const csv =
        `\
productType,name,variantId,slug,key,variantKey
${this.productType.id},${this.newProductName},1,${this.newProductSlug},productKey,variantKey\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
    }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.slug).toEqual({en: this.newProductSlug});
        expect(p.key).toEqual('productKey');
        expect(p.masterVariant.key).toEqual('variantKey');
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should import a product with prices (even when one of them is discounted)', function(done) {
      const csv =
        `\
productType,name,variantId,slug,prices
${this.productType.id},${this.newProductName},1,${this.newProductSlug},EUR 899;CH-EUR 999;DE-EUR 999|799;CH-USD 77777700 #${CHANNEL_KEY}\
`;

      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
    }).then(function(result) {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(_.size(p.masterVariant.prices)).toBe(4);
        const { prices } = p.masterVariant;
        expect(prices[0].value).toEqual(jasmine.objectContaining({currencyCode: 'EUR', centAmount: 899}));
        expect(prices[1].value).toEqual(jasmine.objectContaining({currencyCode: 'EUR', centAmount: 999}));
        expect(prices[1].country).toBe('CH');
        expect(prices[2].country).toBe('DE');
        expect(prices[2].value).toEqual(jasmine.objectContaining({currencyCode: 'EUR', centAmount: 999}));
        expect(prices[3].channel.typeId).toBe('channel');
        expect(prices[3].channel.id).toBeDefined();
        return done();}).catch(err => done(_.prettify(err)));
    });

    it('should do nothing on 2nd import run', function(done) {
      const csv =
        `\
productType,name,variantId,slug
${this.productType.id},${this.newProductName},1,${this.newProductSlug}\
`;
      return this.importer.import(csv)
      .then(function(result) {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');

        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);}).then(function(result) {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');
        return done();}).catch(err => done(_.prettify(err)));
    });

    it('should update changes on 2nd import run', function(done) {
      let csv =
        `\
productType,name,variantId,slug
${this.productType.id},${this.newProductName},1,${this.newProductSlug}\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,name,variantId,slug,key,variantKey
${this.productType.id},${this.newProductName+'_changed'},1,${this.newProductSlug},productKey,variantKey\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: `${this.newProductName}_changed`});
        expect(p.slug).toEqual({en: this.newProductSlug});
        expect(p.key).toEqual('productKey');
        expect(p.masterVariant.key).toEqual('variantKey');

        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should handle all kind of attributes and constraints', function(done) {
      let csv =
        `\
productType,name,variantId,slug,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},${TEXT_ATTRIBUTE_NONE},${SET_ATTRIBUTE_TEXT_UNIQUE},${ENUM_ATTRIBUTE_SAME_FOR_ALL},${REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE}
${this.productType.id},${this.newProductName},1,${this.newProductSlug},CU1,10,foo,uno;due,enum1
,,2,slug,CU2,20,foo,tre;quattro,enum2
,,3,slug,CU3,30,foo,cinque;sei,enum2,${this.productType.id}\
`;
      return this.importer.import(csv)
      .then(function(result) {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);}).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');
        csv =
          `\
productType,name,variantId,slug,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},${TEXT_ATTRIBUTE_NONE},${SET_ATTRIBUTE_TEXT_UNIQUE},${ENUM_ATTRIBUTE_SAME_FOR_ALL},${REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE}
${this.productType.id},${this.newProductName},1,${this.newProductSlug},CU1,10,bar,uno;due,enum2
,,2,slug,CU2,10,bar,tre;quattro,enum2,${this.productType.id}
,,3,slug,CU3,10,bar,cinque;sei,enum2,${this.productType.id}\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.masterVariant.attributes[0]).toEqual({name: TEXT_ATTRIBUTE_NONE, value: 'bar'});
        expect(p.masterVariant.attributes[1]).toEqual({name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['uno', 'due']});
        expect(p.masterVariant.attributes[2]).toEqual({name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'CU1'}});
        expect(p.masterVariant.attributes[3]).toEqual({name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10});
        expect(p.masterVariant.attributes[4]).toEqual({name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}});
        expect(p.masterVariant.attributes[5]).toBeUndefined();
        expect(p.variants[0].attributes[0]).toEqual({name: TEXT_ATTRIBUTE_NONE, value: 'bar'});
        expect(p.variants[0].attributes[1]).toEqual({name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['tre', 'quattro']});
        expect(p.variants[0].attributes[2]).toEqual({name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'CU2'}});
        expect(p.variants[0].attributes[3]).toEqual({name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10});
        expect(p.variants[0].attributes[4]).toEqual({name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}});
        expect(p.variants[0].attributes[5]).toEqual({name: REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE, value: {id: this.productType.id, typeId: 'product-type'}});
        expect(p.variants[1].attributes[0]).toEqual({name: TEXT_ATTRIBUTE_NONE, value: 'bar'});
        expect(p.variants[1].attributes[1]).toEqual({name: REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE, value: {id: this.productType.id, typeId: 'product-type'}});
        expect(p.variants[1].attributes[2]).toEqual({name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['cinque', 'sei']});
        expect(p.variants[1].attributes[3]).toEqual({name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'CU3'}});
        expect(p.variants[1].attributes[4]).toEqual({name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10});
        expect(p.variants[1].attributes[5]).toEqual({name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should handle multiple products', function(done) {
      const p1 = TestHelpers.uniqueId('name1-');
      const p2 = TestHelpers.uniqueId('name2-');
      const p3 = TestHelpers.uniqueId('name3-');
      const s1 = TestHelpers.uniqueId('slug1-');
      const s2 = TestHelpers.uniqueId('slug2-');
      const s3 = TestHelpers.uniqueId('slug3-');
      const csv =
        `\
productType,name,variantId,slug,${TEXT_ATTRIBUTE_NONE}
${this.productType.id},${p1},1,${s1}
,,2,slug12,x
${this.productType.id},${p2},1,${s2}
${this.productType.id},${p3},1,${s3}\
`;
      return this.importer.import(csv)
      .then(function(result) {
        expect(_.size(result)).toBe(3);
        expect(result[0]).toBe('[row 2] New product created.');
        expect(result[1]).toBe('[row 4] New product created.');
        expect(result[2]).toBe('[row 5] New product created.');
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);}).then(result => {
        expect(_.size(result)).toBe(3);
        expect(result[0]).toBe('[row 2] Product update not necessary.');
        expect(result[1]).toBe('[row 4] Product update not necessary.');
        expect(result[2]).toBe('[row 5] Product update not necessary.');

        return this.client.productProjections.staged(true)
        .where(`productType(id=\"${this.productType.id}\")`)
        .sort("name.en")
        .fetch();
      }).then(function(result) {
        expect(_.size(result.body.results)).toBe(3);
        expect(result.body.results[0].name).toEqual({en: p1});
        expect(result.body.results[1].name).toEqual({en: p2});
        expect(result.body.results[2].name).toEqual({en: p3});
        expect(result.body.results[0].slug).toEqual({en: s1});
        expect(result.body.results[1].slug).toEqual({en: s2});
        expect(result.body.results[2].slug).toEqual({en: s3});
        return done();}).catch(err => done(_.prettify(err)));
    });

    it('should handle set of enums', function(done) {
      let csv =
        `\
productType,name,variantId,slug,${SET_ATTRIBUTE_ENUM_NONE},${SET_ATTRIBUTE_TEXT_UNIQUE},${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE}
${this.productType.id},${this.newProductName},1,${this.newProductSlug},enum1;enum2,foo;bar,10
,,2,slug2,enum2,foo;bar;baz,20\
`;
      return this.importer.import(csv)
      .then(function(result) {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);}).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');
        csv =
          `\
productType,name,variantId,slug,${SET_ATTRIBUTE_ENUM_NONE},${SET_ATTRIBUTE_TEXT_UNIQUE},${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE}
${this.productType.id},${this.newProductName},1,${this.newProductSlug},enum1,bar,100
,,2,slug2,enum2,foo,200\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');

        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(function(result) {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.masterVariant.attributes[0]).toEqual({name: SET_ATTRIBUTE_ENUM_NONE, value: [{key: 'enum1', label: 'Enum1'}]});
        expect(p.masterVariant.attributes[1]).toEqual({name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['bar']});
        expect(p.masterVariant.attributes[2]).toEqual({name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 100});
        return done();}).catch(err => done(_.prettify(err)));
    });

    it('should handle set of SameForAll enums with new variants', function(done) {
      let csv =
        `\
productType,name,variantId,slug,sku,${SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},${TEXT_ATTRIBUTE_NONE},${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en
${this.productType.id},${this.newProductSlug},1,${this.newProductSlug},${this.newProductSku},lenum1;lenum2,foo,fooEn\
`;
      return this.importer.import(csv)
      .then(function(result) {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        const im = createImporter();
        return im.import(csv);}).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');
        csv =
          `\
productType,name,variantId,slug,sku,${SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},${TEXT_ATTRIBUTE_NONE},${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en
${this.productType.id},${this.newProductName},1,${this.newProductSlug},${this.newProductSku+1},lenum1;lenum2,foo,fooEn1
,,2,,${this.newProductSku+2},lenum1;lenum2,foo,fooEn2
,,3,,${this.newProductSku+3},lenum1;lenum2,foo,fooEn3
,,4,,${this.newProductSku+4},lenum1;lenum2,foo,fooEn4
,,5,,${this.newProductSku+5},lenum1;lenum2,foo,fooEn5
,,6,,${this.newProductSku+6},lenum1;lenum2,foo,fooEn6
,,7,,${this.newProductSku+7},lenum1;lenum2,foo,fooEn7
,,8,,${this.newProductSku+8},lenum1;lenum2,foo,fooEn8
,,9,,${this.newProductSku+9},lenum1;lenum2,foo,fooEn9
,,10,,${this.newProductSku+10},lenum1;lenum2,foo,fooEn10
,,11,,${this.newProductSku+11},lenum1;lenum2,foo,fooEn11
,,12,,${this.newProductSku+12},lenum1;lenum2,foo,fooEn12
,,13,,${this.newProductSku+13},lenum1;lenum2,foo,fooEn13\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.masterVariant.sku).toBe(`${this.newProductSku}1`);
        expect(p.masterVariant.attributes[0]).toEqual({name: TEXT_ATTRIBUTE_NONE, value: 'foo'});
        expect(p.masterVariant.attributes[1]).toEqual({name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'fooEn1'}});
        expect(p.masterVariant.attributes[2]).toEqual({name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum1', label: {en: 'Enum1'}}, {key: 'lenum2', label: {en: 'Enum2'}}]});
        _.each(result.body.results[0].variants, (v, i) => {
          expect(v.sku).toBe(`${this.newProductSku}${i+2}`);
          expect(v.attributes[0]).toEqual({name: TEXT_ATTRIBUTE_NONE, value: 'foo'});
          expect(v.attributes[1]).toEqual({name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: `fooEn${i+2}`}});
          return expect(v.attributes[2]).toEqual({name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum1', label: {en: 'Enum1'}}, {key: 'lenum2', label: {en: 'Enum2'}}]});
      });
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should remove a variant and change an SameForAll attribute at the same time', function(done) {
      let csv =
        `\
productType,name,variantId,slug,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},${ENUM_ATTRIBUTE_SAME_FOR_ALL}
${this.productType.id},${this.newProductSlug},1,${this.newProductSlug},foo,10,enum1
,,2,slug-2,bar,20,\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,name,variantId,slug,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},${ENUM_ATTRIBUTE_SAME_FOR_ALL}
${this.productType.id},${this.newProductName},1,${this.newProductSlug},foo,10,enum1\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(function(result) {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.variants).toEqual([]);
        expect(p.masterVariant.attributes[0]).toEqual({name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'foo'}});
        expect(p.masterVariant.attributes[1]).toEqual({name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10});
        expect(p.masterVariant.attributes[2]).toEqual({name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum1', label: 'Enum1'}});
        return done();}).catch(err => done(_.prettify(err)));
    });

    it('should not removeVariant if allowRemovalOfVariants is off', function(done) {
      let csv =
        `\
productType,name,variantId,slug,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},${ENUM_ATTRIBUTE_SAME_FOR_ALL}
${this.productType.id},${this.newProductName},1,${this.newProductSlug},foo,10,enum1
,,2,slug-2,bar,20,\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,name,variantId,slug,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},${ENUM_ATTRIBUTE_SAME_FOR_ALL}
${this.productType.id},${this.newProductName},1,${this.newProductSlug},foo,10,enum1\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        im.allowRemovalOfVariants = false;
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');

        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(function(result) {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(_.size(p.variants)).toBe(1);
        return done();}).catch(err => done(_.prettify(err)));
    });

    it('should execute SameForAll attribute change before addVariant', function(done) {
      let csv =
        `\
productType,name,variantId,slug,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},${ENUM_ATTRIBUTE_SAME_FOR_ALL}
${this.productType.id},${this.newProductName},1,${this.newProductSlug},foo,10,enum1
,,2,slug-2,bar,20,\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,name,variantId,slug,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},${ENUM_ATTRIBUTE_SAME_FOR_ALL}
${this.productType.id},${this.newProductName},1,${this.newProductSlug},foo,10,enum2
,,2,slug-2,bar,20,enum1\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.slug).toEqual({en: this.newProductSlug});
        expect(p.masterVariant.attributes[0]).toEqual({name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'foo'}});
        expect(p.masterVariant.attributes[1]).toEqual({name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10});
        expect(p.masterVariant.attributes[2]).toEqual({name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}});
        expect(p.variants[0].attributes[0]).toEqual({name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'bar'}});
        expect(p.variants[0].attributes[1]).toEqual({name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 20});
        expect(p.variants[0].attributes[2]).toEqual({name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should do a partial update of product base attributes', function(done) {
      let csv =
        `\
productType,name.en,description.en,slug.en,variantId,searchKeywords.en,searchKeywords.fr
${this.productType.id},${this.newProductName},foo bar,${this.newProductSlug},1,new;search;keywords,nouvelle;trouve\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,slug.en,variantId,searchKeywords.en,searchKeywords.fr
${this.productType.id},${this.newProductSlug},1,new;search;keywords,nouvelle;trouve\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');
        csv =
          `\
productType,slug,name,variantId,sku,searchKeywords.de
${this.productType.id},${this.newProductSlug},${this.newProductName+'_changed'},1,${this.newProductSku},neue;such;schlagwoerter\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');

        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: `${this.newProductName}_changed`});
        expect(p.description).toEqual({en: 'foo bar'});
        expect(p.slug).toEqual({en: this.newProductSlug});
        expect(p.masterVariant.sku).toBe(this.newProductSku);
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should do a partial update of search keywords', function(done) {
      const sku = cuid();
      return this.client.products.create({
        name: {
          en: this.newProductName
        },
        productType: {
          id: this.productType.id,
          type: 'product-type'
        },
        slug: {
          en: this.newProductSlug
        },
        searchKeywords: {
          en: [
            { text: "new" },
            { text: "search" },
            { text: "keywords" }
          ],
          fr: [
            { text: "nouvelle" },
            { text: "trouve" }
          ],
          de: [
            { text: "deutsche" },
            { text: "kartoffel" }
          ]
        },
        masterVariant: {
          sku
        }}).then(({ body: { masterData: { current: { masterVariant } } } }) => {
        const csv =
          `\
productType,variantId,sku,searchKeywords.en,searchKeywords.fr
${this.productType.id},${masterVariant.id},${masterVariant.sku},newNew;search;keywords,nouvelleNew;trouveNew\
`;
        const im = createImporter();
        return im.import(csv);
        }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`name (en = \"${this.newProductName}\")`).fetch();
      }).then(function(result) {
        expect(result.body.results[0].searchKeywords).toEqual({
          "en": [
            {
              "text": "newNew"
            },
            {
              "text": "search"
            },
            {
              "text": "keywords"
            }
          ],
          "fr": [
            {
              "text": "nouvelleNew"
            },
            {
              "text": "trouveNew"
            }
          ]});
        return done();}).catch(err => done(_.prettify(err)));
    });

    it('should do a partial update of localized attributes', function(done) {
      let csv =
        `\
productType,variantId,sku,name,description.en,description.de,description.fr,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.de,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.it
${this.productType.id},1,${this.newProductSku},${this.newProductName},foo bar,bla bla,bon jour,english,german,italian\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,variantId,sku
${this.productType.id},1,${this.newProductSku}\
`;
        const im = createImporter();
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');
        csv =
          `\
productType,variantId,sku,description.de,description.fr,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.it
${this.productType.id},1,${this.newProductSku},"Hallo Welt",bon jour,english,ciao\
`;
        const im = createImporter();
        return im.import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');

        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(function(result) {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        // TODO: expecting 'foo bar'
        expect(p.description).toEqual({en: undefined, de: 'Hallo Welt', fr: 'bon jour'});
        // TODO: expecting {de: 'german'}
        expect(p.masterVariant.attributes[0]).toEqual({name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'english', de: undefined, it: 'ciao'}});
        return done();}).catch(err => done(_.prettify(err)));
    });

    it('should do a partial update of custom attributes', function(done) {
      let csv =
        `\
productType,name,slug,variantId,${TEXT_ATTRIBUTE_NONE},${SET_ATTRIBUTE_TEXT_UNIQUE},${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},${ENUM_ATTRIBUTE_SAME_FOR_ALL},${SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},sku
${this.productType.id},${this.newProductName},${this.newProductSlug},1,hello,foo1;bar1,June,10,enum1,lenum1;lenum2,${this.newProductSku+1}
,,,2,hello,foo2;bar2,October,20,,,${this.newProductSku+2}\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,variantId,sku
${this.productType.id},1,${this.newProductSku+1}
,2,${this.newProductSku+2}\
`;
        const im = createImporter();
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');
        csv =
        `\
productType,name,slug,variantId,${SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},${SET_ATTRIBUTE_TEXT_UNIQUE},sku
${this.productType.id},${this.newProductName},${this.newProductSlug},1,lenum2,unique,${this.newProductSku+1}
,,,2,,still-unique,${this.newProductSku+2}\
`;
        const im = createImporter();
        return im.import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(_.size(p.variants)).toBe(1);
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.masterVariant.sku).toBe(`${this.newProductSku}1`);
        expect(p.masterVariant.attributes[0]).toEqual({ name: TEXT_ATTRIBUTE_NONE, value: 'hello' });
        expect(p.masterVariant.attributes[1]).toEqual({ name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['unique'] });
        expect(p.masterVariant.attributes[2]).toEqual({ name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'June'} });
        expect(p.masterVariant.attributes[3]).toEqual({ name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10 });
        expect(p.masterVariant.attributes[4]).toEqual({ name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum1', label: 'Enum1'} });
        expect(p.masterVariant.attributes[5]).toEqual({ name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum2', label: { en: 'Enum2' }}] });
        expect(p.variants[0].sku).toBe(`${this.newProductSku}2`);
        expect(p.variants[0].attributes[0]).toEqual({ name: TEXT_ATTRIBUTE_NONE, value: 'hello' });
        expect(p.variants[0].attributes[1]).toEqual({ name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['still-unique'] });
        expect(p.variants[0].attributes[2]).toEqual({ name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'October'} });
        expect(p.variants[0].attributes[3]).toEqual({ name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 20 });
        expect(p.variants[0].attributes[4]).toEqual({ name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum1', label: 'Enum1'} });
        expect(p.variants[0].attributes[5]).toEqual({ name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum2', label: { en: 'Enum2' }}] });
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('partial update should not overwrite name, prices and images', function(done) {
      let csv =
        `\
productType,name,slug,variantId,prices,images
${this.productType.id},${this.newProductName},${this.newProductSlug},1,EUR 999,//example.com/foo.jpg
,,,2,USD 70000,/example.com/bar.png\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,slug,variantId
${this.productType.id},${this.newProductSlug},1
,,2\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');

        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.masterVariant.prices[0].value).toEqual(jasmine.objectContaining({centAmount: 999, currencyCode: 'EUR'}));
        expect(p.masterVariant.images[0].url).toBe('//example.com/foo.jpg');
        expect(p.variants[0].prices[0].value).toEqual(jasmine.objectContaining({centAmount: 70000, currencyCode: 'USD'}));
        expect(p.variants[0].images[0].url).toBe('/example.com/bar.png');
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should do a full update of SEO attribute', function(done) {
      let csv =
        `\
productType,variantId,sku,name,metaTitle,metaDescription,metaKeywords
${this.productType.id},1,${this.newProductSku},${this.newProductName},a,b,c\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,variantId,sku,name,metaTitle,metaDescription,metaKeywords
${this.productType.id},1,${this.newProductSku},${this.newProductName},,b,changed\
`;
        const im = createImporter();
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.metaTitle).toEqual(undefined);
        expect(p.metaDescription).toEqual({en: 'b'});
        expect(p.metaKeywords).toEqual({en: 'changed'});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should do a full update of multi language SEO attribute', function(done) {
      let csv =
        `\
productType,variantId,sku,name,metaTitle.de,metaDescription.de,metaKeywords.de,metaTitle.en,metaDescription.en,metaKeywords.en
${this.productType.id},1,${this.newProductSku},${this.newProductName},metaTitleDe,metaDescDe,metaKeyDe,metaTitleEn,metaDescEn,metaKeyEn\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,variantId,sku,name,metaTitle.de,metaDescription.de,metaKeywords.de,metaTitle.en,metaDescription.en,metaKeywords.en
${this.productType.id},1,${this.newProductSku},${this.newProductName},,newMetaDescDe,newMetaKeyDe,newMetaTitleEn,newMetaDescEn\
`;
        const im = createImporter();
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.metaTitle).toEqual({en: 'newMetaTitleEn'});
        expect(p.metaDescription).toEqual({en: 'newMetaDescEn', de: 'newMetaDescDe'});
        expect(p.metaKeywords).toEqual({de: 'newMetaKeyDe'});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should update SEO attribute if not all 3 headers are present', function(done) {
      let csv =
        `\
productType,variantId,sku,name,metaTitle,metaDescription,metaKeywords
${this.productType.id},1,${this.newProductSku},${this.newProductName},a,b,c\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,variantId,sku,name,metaTitle,metaDescription
${this.productType.id},1,${this.newProductSku},${this.newProductName},x,y\
`;
        const im = createImporter();
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.metaTitle).toEqual({en: 'x'});
        expect(p.metaDescription).toEqual({en: 'y'});
        expect(p.metaKeywords).toEqual({en: 'c'});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should do a partial update of prices based on SKUs', function(done) {
      let csv =
      `\
productType,name,sku,variantId,prices
${this.productType.id},${this.newProductName},${this.newProductSku+1},1,EUR 999
,,${this.newProductSku+2},2,USD 70000\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
        `\
sku,prices,productType
${this.newProductSku+1},EUR 1999,${this.productType.name}
${this.newProductSku+2},USD 80000,${this.productType.name}\
`;
        const im = createImporter();
        im.allowRemovalOfVariants = false;
        im.updatesOnly = true;
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.masterVariant.sku).toBe(`${this.newProductSku}1`);
        expect(p.masterVariant.prices[0].value).toEqual(jasmine.objectContaining({centAmount: 1999, currencyCode: 'EUR'}));
        expect(p.variants[0].sku).toBe(`${this.newProductSku}2`);
        expect(p.variants[0].prices[0].value).toEqual(jasmine.objectContaining({centAmount: 80000, currencyCode: 'USD'}));
        return done();
      }).catch(err => done(_.prettify(err)));
    });


    it('should import a simple product with different encoding', function(done) {
      const encoding = "win1250";
      this.importer.options.encoding = encoding;
      this.newProductName += "žýáíé";
      const csv =
      `\
productType,name,variantId,slug
${this.productType.id},${this.newProductName},1,${this.newProductSlug}\
`;
      const encoded = iconv.encode(csv, encoding);
      return this.importer.import(encoded)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
    }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.slug).toEqual({en: this.newProductSlug});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should import a simple product file with different encoding', function(done) {
      const encoding = "win1250";
      this.importer.options.encoding = encoding;
      this.newProductName += "žýáíé";
      const csv =
      `\
productType,name,variantId,slug
${this.productType.id},${this.newProductName},1,${this.newProductSlug}\
`;
      const encoded = iconv.encode(csv, encoding);
      return this.importer.import(encoded)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
    }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.slug).toEqual({en: this.newProductSlug});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should import a simple product file with different encoding using import manager', function(done) {
      const filePath = "/tmp/test-import.csv";
      const encoding = "win1250";
      this.importer.options.encoding = encoding;
      this.newProductName += "žýáíé";
      const csv =
      `\
productType,name,variantId,slug
${this.productType.id},${this.newProductName},1,${this.newProductSlug}\
`;
      const encoded = iconv.encode(csv, encoding);
      fs.writeFileSync(filePath, encoded);

      return this.importer.importManager(filePath)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
    }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.slug).toEqual({en: this.newProductSlug});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should update a product level info based only on SKU', function(done) {
      const newProductNameUpdated = `${this.newProductName}-updated`;
      const categories = TestHelpers.generateCategories(4);

      let csv =
      `\
productType,name,sku,variantId,prices,categories
${this.productType.id},${this.newProductName},${this.newProductSku+1},1,EUR 999,1;2\
`;

      return TestHelpers.ensureCategories(this.client, categories)
      .then(() => {
        return this.importer.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');

        csv =
        `\
productType,sku,name.en,name.it,categories
${this.productType.name},${this.newProductSku+1},${newProductNameUpdated},${newProductNameUpdated}-it,2;3\
`;
        const im = createImporter();
        im.allowRemovalOfVariants = false;
        im.updatesOnly = true;
        return im.import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: newProductNameUpdated, it: `${newProductNameUpdated}-it`});
        expect(_.size(p.categories)).toEqual(2);
        expect(p.masterVariant.sku).toBe(`${this.newProductSku}1`);
        expect(p.masterVariant.prices[0].value).toEqual(jasmine.objectContaining({centAmount: 999, currencyCode: 'EUR'}));
        return done();
      }).catch(function(err) {
        console.dir(err, {depth: 100});
        return done(_.prettify(err));
      });
    });

    it('should update a product level info and multiple variants based only on SKU', function(done) {
      const updatedProductName = `${this.newProductName}-updated`;
      const skuPrefix = "sku-";

      let csv =
      `\
productType,name,sku,variantId,prices
${this.productType.id},${this.newProductName},${skuPrefix+1},1,EUR 899
,,${skuPrefix+3},2,EUR 899
,,${skuPrefix+2},3,EUR 899
,,${skuPrefix+4},4,EUR 899\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');

        csv =
        `\
productType,name,sku,prices
${this.productType.id},${updatedProductName},${skuPrefix+1},EUR 100
,,${skuPrefix+2},EUR 200
,,${skuPrefix+3},EUR 300
,,${skuPrefix+4},EUR 400\
`;

        const im = createImporter();
        im.allowRemovalOfVariants = false;
        im.updatesOnly = true;
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);

        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        const p = result.body.results[0];

        const getPrice = variant => variant != null ? variant.prices[0].value.centAmount : undefined;
        const getVariantBySku = (variants, sku) => _.find(variants, v => v.sku === sku);

        expect(p.name).toEqual({en: updatedProductName});
        expect(p.masterVariant.sku).toBe(`${skuPrefix}1`);
        expect(getPrice(p.masterVariant)).toBe(100);

        expect(_.size(p.variants)).toEqual(3);
        expect(getPrice(getVariantBySku(p.variants, skuPrefix+2))).toBe(200);
        expect(getPrice(getVariantBySku(p.variants, skuPrefix+3))).toBe(300);
        expect(getPrice(getVariantBySku(p.variants, skuPrefix+4))).toBe(400);

        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should update categories only when they are provided in import CSV', function(done) {
      const skuPrefix = "sku-";
      let csv =
      `\
productType,name,sku,variantId,categories
${this.productType.id},${this.newProductName},${skuPrefix}1,1,1;2\
`;

      const categories = TestHelpers.generateCategories(10);

      const getImporter = function() {
        const im = createImporter();
        im.allowRemovalOfVariants = false;
        im.updatesOnly = true;
        return im;
      };

      const getCategoryByExternalId = (list, id) => _.find(list, item => item.obj.externalId === String(id));

      return TestHelpers.ensureCategories(this.client, categories)
      .then(() => {
        return this.importer.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');

        csv =
        `\
productType,sku
${this.productType.id},${skuPrefix+1}\
`;

        return getImporter().import(csv);
      }).then(result => {
        expect(result[0]).toBe('[row 2] Product update not necessary.');

        csv =
        `\
productType,sku,categories
${this.productType.id},${skuPrefix+1},3;4\
`;

        return getImporter().import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');

        return this.client.productProjections
        .staged(true)
        .expand("categories[*]")
        .where(`productType(id=\"${this.productType.id}\")`)
        .fetch();
      }).then(result => {
        const p = result.body.results[0];

        expect(p.name).toEqual({en: this.newProductName});
        expect(p.masterVariant.sku).toBe(`${skuPrefix}1`);

        expect(_.size(p.categories)).toEqual(2);
        expect(!!getCategoryByExternalId(p.categories, 3)).toBe(true);
        expect(!!getCategoryByExternalId(p.categories, 4)).toBe(true);

        return done();
      }).catch(err => done(_.prettify(err)));
    });



    it('should clear categories when an empty value given', function(done) {
      const skuPrefix = "sku-";
      let csv =
      `\
productType,name,sku,variantId,categories
${this.productType.id},${this.newProductName},${skuPrefix}1,1,1;2\
`;

      const categories = TestHelpers.generateCategories(4);

      const getImporter = function() {
        const im = createImporter();
        im.allowRemovalOfVariants = false;
        im.updatesOnly = true;
        return im;
      };

      return TestHelpers.ensureCategories(this.client, categories)
      .then(() => {
        return this.importer.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');

        csv =
        `\
productType,sku,categories
${this.productType.id},${skuPrefix+1},\
`;

        return getImporter().import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');

        return this.client.productProjections
        .staged(true)
        .where(`productType(id=\"${this.productType.id}\")`)
        .fetch();
      }).then(result => {
        const p = result.body.results[0];
        expect(_.size(p.categories)).toBe(0);

        csv =
        `\
productType,sku,categories
${this.productType.id},${skuPrefix+1},3;4\
`;

        return getImporter().import(csv);
      }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');

        return this.client.productProjections
        .staged(true)
        .where(`productType(id=\"${this.productType.id}\")`)
        .fetch();
      }).then(result => {
        const p = result.body.results[0];
        expect(_.size(p.categories)).toBe(2);

        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should handle a concurrent modification error when updating by SKU', function(done) {
      let j;
      let i;
      const skuPrefix = "sku-";

      let csv =
        `\
productType,name,sku,variantId,prices
${this.productType.id},${this.newProductName},${skuPrefix+1},1,EUR 100\
`;
      for (j = 2, i = j; j < 41; j++, i = j) {
        csv += `\n,,${skuPrefix+i},${i},EUR 100`;
      }

      return this.importer.import(csv)
        .then(() => {
          return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
          const p = result.body.results[0];
          expect(p.variants.length).toEqual(39);
          csv =
            `\
sku,productType,prices\
`;

          for (i = 1; i < 41; i++) {
            csv += `\n${skuPrefix+i},${this.productType.id},EUR 200`;
          }

          const im = createImporter();
          im.allowRemovalOfVariants = false;
          im.updatesOnly = true;
          return im.import(csv);
        }).then(() => {
          return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
        }).then(result => {
          const p = result.body.results[0];
          p.variants.push(p.masterVariant);

          p.variants.forEach(v => {
            return console.log(v.sku, ":", v.prices[0].value.centAmount);
          });

          expect(p.variants.length).toEqual(40);
          p.variants.forEach(variant => expect(variant.prices[0].value.centAmount).toEqual(200));

          return done();
        }).catch(err => done(_.prettify(err)));
    });


    it('should handle a concurrent modification error when updating by variantId', function(done) {
      let j;
      let i;
      const skuPrefix = "sku-";

      let csv =
        `\
productType,name,sku,variantId,prices\
`;
      for (j = 1, i = j; j < 2; j++, i = j) {
        csv += `\n${this.productType.id},${this.newProductName+i},${skuPrefix+i},1,EUR 100`;
      }

      return this.importer.import(csv)
      .then(() => {
        csv =
          `\
productType,name,sku,variantId,prices\
`;
        for (i = 1; i < 5; i++) {
          csv += `\n${this.productType.id},${this.newProductName+i},${skuPrefix}1,1,EUR 2${i}`;
        }

        const im = createImporter();
        im.allowRemovalOfVariants = false;
        im.updatesOnly = true;
        return im.import(csv);
    }).then(() =>
        // no concurrentModification found
        done()).catch(err => done(_.prettify(err)));
    });

    return it('should split actions if there are more than 500 in actions array', function(done) {
      const numberOfVariants = 501;
      
      const csvCreator = function(productType, newProductName, newProductSlug, rows) {
        let changes = "";
        let i = 0;
        while (i < rows) {
          changes += `${productType.id},${newProductName},${1+i},${newProductSlug},${`productKey${i}`},${`variantKey${i}`}\n`;
          i++;
        }
        const csv =
        `\
${changes}\
`;
        return csv;
      };

      let csv =
        `\
productType,name,variantId,slug,key,variantKey
${this.productType.id},${this.newProductName},1,${this.newProductSlug},productKey0,variantKey0"\
`;
      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        csv =
          `\
productType,name,variantId,slug,key,variantKey
${csvCreator(this.productType, this.newProductName, this.newProductSlug, numberOfVariants)}\
`;
        const im = createImporter();
        im.matchBy = 'slug';
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(1);
        const p = result.body.results[0];
        expect(p.name).toEqual({en: `${this.newProductName}`});
        expect(p.slug).toEqual({en: this.newProductSlug});
        expect(p.key).toEqual('productKey0');
        expect(p.masterVariant.key).toEqual('variantKey0');
        expect(p.variants.length).toBe(numberOfVariants-1);

        return done();
      }).catch(err => done(_.prettify(err)));
    });
  });
});
