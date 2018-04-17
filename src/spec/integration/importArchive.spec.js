/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Promise = require('bluebird');
const _ = require('underscore');
const archiver = require('archiver');
_.mixin(require('underscore-mixins'));
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


const createImporter = function(format) {
  const config = JSON.parse(JSON.stringify(Config)); // cloneDeep
  config.importFormat = format || "csv";
  const im = new Import(config);
  im.matchBy = 'sku';
  im.allowRemovalOfVariants = true;
  im.suppressMissingHeaderWarning = true;
  return im;
};

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

describe('Import integration test', function() {

  beforeEach(function(done) {
    jasmine.getEnv().defaultTimeoutInterval = 90000; // 90 sec
    this.importer = createImporter();
    this.importer.suppressMissingHeaderWarning = true;
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

    it('should import multiple archived products from CSV', function(done) {
      let p;
      const tempDir = tmp.dirSync({ unsafeCleanup: true });
      const archivePath = path.join(tempDir.name, 'products.zip');

      const csv = [
        `\
productType,name,variantId,slug
${this.productType.id},${this.newProductName},1,${this.newProductSlug}\
`,
        `\
productType,name,variantId,slug
${this.productType.id},${this.newProductName+1},1,${this.newProductSlug+1}\
`
      ];

      return Promise.map(csv, (content, index) => fs.writeFileAsync(path.join(tempDir.name, `products-${index}.csv`), content)).then(function() {
        const archive = archiver('zip');
        const outputStream = fs.createWriteStream(archivePath);

        return new Promise(function(resolve, reject) {
          outputStream.on('close', () => resolve());
          archive.on('error', err => reject(err));
          archive.pipe(outputStream);

          archive.bulk([
            { expand: true, cwd: tempDir.name, src: ['**'], dest: 'products'}
          ]);
          return archive.finalize();
        });}).then(() => {
        return this.importer.importManager(archivePath, true);
      }).then(() => {
        return this.client.productProjections.staged(true)
          .sort("createdAt", "ASC")
          .where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {},
        expect(_.size(result.body.results)).toBe(2),

        (p = result.body.results[0]),
        expect(p.name).toEqual({en: this.newProductName}),
        expect(p.slug).toEqual({en: this.newProductSlug}),

        (p = result.body.results[1]),
        expect(p.name).toEqual({en: this.newProductName+1}),
        expect(p.slug).toEqual({en: this.newProductSlug+1}),

        done()).catch(err => done(_.prettify(err)))
      .finally(() => tempDir.removeCallback());
    });

    return it('should import multiple archived products from XLSX', function(done) {
      const importer = createImporter("xlsx");
      const tempDir = tmp.dirSync({ unsafeCleanup: true });
      const archivePath = path.join(tempDir.name, 'products.zip');

      const data = [
        [
          ["productType","name","variantId","slug"],
          [this.productType.id,this.newProductName,1,this.newProductSlug]
        ],
        [
          ["productType","name","variantId","slug"],
          [this.productType.id,this.newProductName+1,1,this.newProductSlug+1]
        ]
      ];

      return Promise.map(data, (content, index) => writeXlsx(path.join(tempDir.name, `products-${index}.xlsx`), content)).then(function() {
        const archive = archiver('zip');
        const outputStream = fs.createWriteStream(archivePath);

        return new Promise(function(resolve, reject) {
          outputStream.on('close', () => resolve());
          archive.on('error', err => reject(err));
          archive.pipe(outputStream);

          archive.bulk([
            { expand: true, cwd: tempDir.name, src: ['**'], dest: 'products'}
          ]);
          return archive.finalize();
        });}).then(() => {
        return importer.importManager(archivePath, true);
      }).then(() => {
        return this.client.productProjections.staged(true)
        .sort("createdAt", "ASC")
        .where(`productType(id=\"${this.productType.id}\")`).fetch();
      }).then(result => {
        expect(_.size(result.body.results)).toBe(2);

        let p = result.body.results[0];
        expect(p.name).toEqual({en: this.newProductName});
        expect(p.slug).toEqual({en: this.newProductSlug});

        p = result.body.results[1];
        expect(p.name).toEqual({en: this.newProductName+1});
        expect(p.slug).toEqual({en: this.newProductSlug+1});

        return done();
      }).catch(err => done(_.prettify(err)))
      .finally(() => tempDir.removeCallback());
    });
  });
});
