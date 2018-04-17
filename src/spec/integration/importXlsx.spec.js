/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
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
const Excel = require('exceljs');
const cuid = require('cuid');
const path = require('path');
const tmp = require('tmp');
const fs = Promise.promisifyAll(require('fs'));
// will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup();
const CHANNEL_KEY = 'retailerA';


const writeXlsx = function(filePath, data) {
  const workbook = new Excel.Workbook();
  workbook.created = new Date();
  const worksheet = workbook.addWorksheet('Products');
  console.log("Generating Xlsx file");

  data.forEach(function(items, index) {
    if (index) {
      return worksheet.addRow(items);
    } else {
      const headers = [];
      for (let i in items) {
        headers.push({
          header: items[i]
        });
      }
      return worksheet.columns = headers;
    }
  });

  return workbook.xlsx.writeFile(filePath);
};

const createImporter = function() {
  Config.importFormat = "xlsx";
  const im = new Import(Config);
  im.matchBy = 'sku';
  im.allowRemovalOfVariants = true;
  im.suppressMissingHeaderWarning = true;
  return im;
};

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

  return describe('#importXlsx', function() {

    beforeEach(function() {
      this.newProductName = TestHelpers.uniqueId('name-');
      this.newProductSlug = TestHelpers.uniqueId('slug-');
      return this.newProductSku = TestHelpers.uniqueId('sku-');
    });

    it('should import a simple product from xlsx', function(done) {
      const filePath = "/tmp/test-import.xlsx";
      const data = [
        ["productType","name","variantId","slug"],
        [this.productType.id,this.newProductName,1,this.newProductSlug]
      ];

      return writeXlsx(filePath, data)
      .then(() => {
        return this.importer.importManager(filePath);
    }).then(result => {
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

    it('should import a product with prices (even when one of them is discounted)', function(done) {
      const filePath = "/tmp/test-import.xlsx";
      const data = [
        ["productType","name","variantId","slug","prices"],
        [this.productType.id,this.newProductName,1,this.newProductSlug,`EUR 899;CH-EUR 999;DE-EUR 999|799;CH-USD 77777700 #${CHANNEL_KEY}`]
      ];

      return writeXlsx(filePath, data)
      .then(() => {
        return this.importer.importManager(filePath);
    }).then(result => {
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
      const filePath = "/tmp/test-import.xlsx";
      const data = [
        ["productType","name","variantId","slug"],
        [this.productType.id,this.newProductName,1,this.newProductSlug]
      ];

      return writeXlsx(filePath, data)
      .then(() => {
        return this.importer.importManager(filePath);
    }).then(function(result) {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');

        const im = createImporter();
        im.matchBy = 'slug';
        return im.importManager(filePath);}).then(function(result) {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] Product update not necessary.');
        return done();}).catch(err => done(_.prettify(err)));
    });


    return it('should do a partial update of prices based on SKUs', function(done) {
      const filePath = "/tmp/test-import.xlsx";
      const data = [
        ["productType","name","sku","variantId","prices"],
        [this.productType.id,this.newProductName,this.newProductSku+1,1,"EUR 999"],
        [null,null,this.newProductSku+2,2,"USD 70000"]
      ];

      return writeXlsx(filePath, data)
      .then(() => {
        return this.importer.importManager(filePath);
    }).then(result => {
        expect(_.size(result)).toBe(1);
        expect(result[0]).toBe('[row 2] New product created.');
        const csv =
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
  });
});
