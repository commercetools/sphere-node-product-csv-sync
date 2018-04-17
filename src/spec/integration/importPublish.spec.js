/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Promise = require('bluebird');
const _ = require('underscore');
_.mixin(require('underscore-mixins'));
const {Import} = require('../../lib/main');
const Config = require('../../config');
const TestHelpers = require('./testhelpers');
const cuid = require('cuid');
const path = require('path');
const tmp = require('tmp');
const fs = Promise.promisifyAll(require('fs'));
// will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup();

const createImporter = function() {
  const im = new Import(Config);
  im.matchBy = 'sku';
  im.allowRemovalOfVariants = true;
  im.suppressMissingHeaderWarning = true;
  return im;
};

const CHANNEL_KEY = 'retailerA';

describe('Import and publish test', function() {

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
      return this.newProductSku = TestHelpers.uniqueId('sku-');
    });

    it('should import products and publish them afterward', function(done) {
      const csv =
        `\
productType,name,variantId,slug,publish
${this.productType.id},${this.newProductName},1,${this.newProductSlug},true
${this.productType.id},${this.newProductName}1,1,${this.newProductSlug}1,false\
`;

      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(2);
        expect(result).toEqual([
          '[row 2] New product created.',
          '[row 3] New product created.'
        ]);
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
    }).then(result => {
        expect(_.size(result.body.results)).toBe(2);
        const products = result.body.results;
        let p = _.where(products, { published: true});
        expect(p.length).toBe(1);
        expect(p[0].slug).toEqual({en: this.newProductSlug});

        p = _.where(products, { published: false});
        expect(p.length).toBe(1);
        expect(p[0].slug).toEqual({en: `${this.newProductSlug}1`});
        return done();
      }).catch(err => done(_.prettify(err)));
    });


    it('should update products and publish them afterward', function(done) {
      let csv =
        `\
productType,variantId,sku,name,publish
${this.productType.id},1,${this.newProductSku},${this.newProductName},true
${this.productType.id},1,${this.newProductSku}1,${this.newProductName}1,true\
`;

      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(2);

        csv =
          `\
productType,variantId,sku,name,publish
${this.productType.id},1,${this.newProductSku},${this.newProductName}2,true
${this.productType.id},1,${this.newProductSku}1,${this.newProductName}12,\
`;
        const im = createImporter();
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(2);
        expect(result).toEqual([
          '[row 2] Product updated.',
          '[row 3] Product updated.'
        ]);
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        const products = _.where(result.body.results, { published: true });
        expect(_.size(products)).toBe(2);

        let p = _.where(products, { hasStagedChanges: false });
        expect(p.length).toBe(1);
        expect(p[0].name).toEqual({en: `${this.newProductName}2`});

        p = _.where(products, { hasStagedChanges: true });
        expect(p.length).toBe(1);
        expect(p[0].name).toEqual({en: `${this.newProductName}12`});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should update and publish product when matching using SKU', function(done) {
      let csv =
        `\
productType,variantId,name,sku,publish
${this.productType.id},1,${this.newProductName}1,${this.newProductSku}1,true
,2,,${this.newProductSku}2,false
${this.productType.id},1,${this.newProductName}3,${this.newProductSku}3,true\
`;

      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(2);
        expect(result).toEqual([
          '[row 2] New product created.',
          '[row 4] New product created.'
        ]);

        csv =
          `\
productType,sku,prices,publish
${this.productType.id},${this.newProductSku}1,EUR 111,true
${this.productType.id},${this.newProductSku}2,EUR 222,false
${this.productType.id},${this.newProductSku}3,EUR 333,false\
`;
        const im = createImporter();
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(2);
        expect(result).toEqual([
          '[row 2] Product updated.',
          '[row 4] Product updated.'
        ]);
        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        const products = _.where(result.body.results, { published: true });
        expect(_.size(products)).toBe(2);

        let p = _.where(products, { hasStagedChanges: false });
        expect(p.length).toBe(1);
        expect(p[0].variants.length).toBe(1);
        expect(p[0].name).toEqual({en: `${this.newProductName}1`});
        expect(p[0].masterVariant.prices[0].value).toEqual(jasmine.objectContaining({currencyCode: 'EUR', centAmount: 111}));
        expect(p[0].variants[0].prices[0].value).toEqual(jasmine.objectContaining({currencyCode: 'EUR', centAmount: 222}));

        p = _.where(products, { hasStagedChanges: true });
        expect(p.length).toBe(1);
        expect(p[0].name).toEqual({en: `${this.newProductName}3`});
        expect(p[0].masterVariant.prices[0].value).toEqual(jasmine.objectContaining({currencyCode: 'EUR', centAmount: 333}));

        return done();
      }).catch(err => done(_.prettify(err)));
    });

    return it('should publish even if there are no update actions', function(done) {
      let csv =
        `\
productType,variantId,name,sku
${this.productType.id},1,${this.newProductName}1,${this.newProductSku}1
,2,,${this.newProductSku}2
${this.productType.id},1,${this.newProductName}3,${this.newProductSku}3\
`;

      return this.importer.import(csv)
      .then(result => {
        expect(_.size(result)).toBe(2);
        expect(result).toEqual([
          '[row 2] New product created.',
          '[row 4] New product created.'
        ]);

        csv =
          `\
productType,sku,publish
${this.productType.id},${this.newProductSku}1,true
${this.productType.id},${this.newProductSku}3,false\
`;
        const im = createImporter();
        return im.import(csv);
    }).then(result => {
        expect(_.size(result)).toBe(2);
        expect(result).toEqual([
          '[row 2] Product updated.',
          '[row 3] Product update not necessary.'
        ]);

        return this.client.productProjections.staged(true).where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        let p = _.where(result.body.results, { published: true });
        expect(p.length).toBe(1);
        expect(p[0].name).toEqual({en: `${this.newProductName}1`});

        p = _.where(result.body.results, { published: false });
        expect(p.length).toBe(1);
        expect(p[0].name).toEqual({en: `${this.newProductName}3`});

        return done();
      }).catch(err => done(_.prettify(err)));
    });
  });
});

