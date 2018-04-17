/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const path = require('path');
const iconv = require('iconv-lite');
_.mixin(require('underscore-mixins'));
const Promise = require('bluebird');
const fs = Promise.promisifyAll(require('fs'));
const Config = require('../../config');
const TestHelpers = require('./testhelpers');
const {Export} = require('../../lib/main');
const extract = require('extract-zip');
const extractArchive = Promise.promisify(extract);
const tmp = require('tmp');
// will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup();

describe('Export integration tests', function() {

  beforeEach(function(done) {
    jasmine.getEnv().defaultTimeoutInterval = 30000; // 30 sec
    this.export = new Export({client: Config});
    this.client = this.export.client;
    this.productType = TestHelpers.mockProductType();

    this.product = {
      key: 'productKey',
      productType: {
        typeId: 'product-type',
        id: 'TODO'
      },
      name: {
        en: 'Foo'
      },
      slug: {
        en: 'foo'
      },
      variants: [{
        key: 'variantKey',
        sku: '123',
        attributes: [
          {
            name: "attr-lenum-n",
            value: {
              key: "lenum1",
              label: {
                en: "Enum1"
              }
            }
          }, {
          name: "attr-set-lenum-n",
          value: [
            {
              key: "lenum1",
              label: {
                en: "Enum1"
              }
            },
            {
              key: "lenum2",
              label: {
                en: "Enum2"
              }
            }
          ]
        }
        ]
      }
      ]
    };

    return TestHelpers.setupProductType(this.client, this.productType, this.product)
    .then(() => done())
    .catch(err => done(_.prettify(err.body)));
  }
  , 60000); // 60sec


  it('should inform about a bad header in the template', function(done) {
    const template =
      `\
productType,name,name\
`;
    return this.export.exportDefault(template, null)
    .then(() => done('Export should fail!')).catch(function(err) {
      expect(_.size(err)).toBe(2);
      expect(err[0]).toBe('There are duplicate header entries!');
      expect(err[1]).toBe("You need either the column 'variantId' or 'sku' to identify your variants!");
      return done();
    });
  });

  it('should inform that there are no products', function(done) {
    const template =
      `\
productType,name,variantId\
`;
    const outputLocation = '/tmp/output.csv';
    const expectedCSV =
      `\
productType,name,variantId
\
`;
    return this.export.exportDefault(template, outputLocation, false)
    .then(function(result) {
      expect(result).toBe('Export done.');
      return fs.readFileAsync(outputLocation, {encoding: 'utf8'});})
    .then(function(content) {
      expect(content).toBe(expectedCSV);
      return done();}).catch(err => done(_.prettify(err)));
  });

  it('should export based on minimum template', function(done) {
    const template =
      `\
productType,name,variantId\
`;
    const outputLocation = '/tmp/output.csv';
    const expectedCSV =
      `\
productType,name,variantId
${this.productType.name},,1
,,2
\
`;
    return this.export.exportDefault(template, outputLocation)
    .then(function(result) {
      expect(result).toBe('Export done.');
      return fs.readFileAsync(outputLocation, {encoding: 'utf8'});})
    .then(function(content) {
      expect(content).toBe(expectedCSV);
      return done();}).catch(err => done(_.prettify(err)));
  });

  it('should export labels of lenum and set of lenum', function(done) {
    const template =
    `\
productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en\
`;
    const outputLocation = '/tmp/output.csv';
    const expectedCSV =
    `\
productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en
${this.productType.name},,1
,,2,Enum1,Enum1;Enum2
\
`;
    return this.export.exportDefault(template, outputLocation)
    .then(function(result) {
      expect(result).toBe('Export done.');
      return fs.readFileAsync(outputLocation, {encoding: 'utf8'});})
    .then(function(content) {
      expect(content).toBe(expectedCSV);
      return done();}).catch(err => done(_.prettify(err)));
  });


  it('should do a full export', function(done) {
    const tempDir = tmp.dirSync({ unsafeCleanup: true });
    const outputLocation = path.join(tempDir.name, 'output.zip');
    const expectedHeader = '_published,_hasStagedChanges,productType,variantId,variantKey,id,key,sku,prices,tax,categories,images,name.en,description.en,slug.en,metaTitle.en,metaDescription.en,metaKeywords.en,searchKeywords.en,attr-text-n,attr-ltext-n.en,attr-enum-n,attr-lenum-n,attr-number-n,attr-boolean-n,attr-money-n,attr-date-n,attr-time-n,attr-datetime-n,attr-ref-product-n,attr-ref-product-type-n,attr-ref-channel-n,attr-ref-state-n,attr-ref-zone-n,attr-ref-shipping-method-n,attr-ref-category-n,attr-ref-review-n,attr-ref-key-value-n,attr-set-text-n,attr-set-ltext-n.en,attr-set-enum-n,attr-set-lenum-n,attr-set-number-n,attr-set-boolean-n,attr-set-money-n,attr-set-date-n,attr-set-time-n,attr-set-datetime-n,attr-set-ref-product-n,attr-set-ref-product-type-n,attr-set-ref-channel-n,attr-set-ref-state-n,attr-set-ref-zone-n,attr-set-ref-shipping-method-n,attr-set-ref-category-n,attr-set-ref-review-n,attr-set-ref-key-value-n,attr-text-u,attr-ltext-u.en,attr-enum-u,attr-lenum-u,attr-number-u,attr-boolean-u,attr-money-u,attr-date-u,attr-time-u,attr-datetime-u,attr-ref-product-u,attr-ref-product-type-u,attr-ref-channel-u,attr-ref-state-u,attr-ref-zone-u,attr-ref-shipping-method-u,attr-ref-category-u,attr-ref-review-u,attr-ref-key-value-u,attr-set-text-u,attr-set-ltext-u.en,attr-set-enum-u,attr-set-lenum-u,attr-set-number-u,attr-set-boolean-u,attr-set-money-u,attr-set-date-u,attr-set-time-u,attr-set-datetime-u,attr-set-ref-product-u,attr-set-ref-product-type-u,attr-set-ref-channel-u,attr-set-ref-state-u,attr-set-ref-zone-u,attr-set-ref-shipping-method-u,attr-set-ref-category-u,attr-set-ref-review-u,attr-set-ref-key-value-u,attr-text-cu,attr-ltext-cu.en,attr-enum-cu,attr-lenum-cu,attr-number-cu,attr-boolean-cu,attr-money-cu,attr-date-cu,attr-time-cu,attr-datetime-cu,attr-ref-product-cu,attr-ref-product-type-cu,attr-ref-channel-cu,attr-ref-state-cu,attr-ref-zone-cu,attr-ref-shipping-method-cu,attr-ref-category-cu,attr-ref-review-cu,attr-ref-key-value-cu,attr-set-text-cu,attr-set-ltext-cu.en,attr-set-enum-cu,attr-set-lenum-cu,attr-set-number-cu,attr-set-boolean-cu,attr-set-money-cu,attr-set-date-cu,attr-set-time-cu,attr-set-datetime-cu,attr-set-ref-product-cu,attr-set-ref-product-type-cu,attr-set-ref-channel-cu,attr-set-ref-state-cu,attr-set-ref-zone-cu,attr-set-ref-shipping-method-cu,attr-set-ref-category-cu,attr-set-ref-review-cu,attr-set-ref-key-value-cu,attr-text-sfa,attr-ltext-sfa.en,attr-enum-sfa,attr-lenum-sfa,attr-number-sfa,attr-boolean-sfa,attr-money-sfa,attr-date-sfa,attr-time-sfa,attr-datetime-sfa,attr-ref-product-sfa,attr-ref-product-type-sfa,attr-ref-channel-sfa,attr-ref-state-sfa,attr-ref-zone-sfa,attr-ref-shipping-method-sfa,attr-ref-category-sfa,attr-ref-review-sfa,attr-ref-key-value-sfa,attr-set-text-sfa,attr-set-ltext-sfa.en,attr-set-enum-sfa,attr-set-lenum-sfa,attr-set-number-sfa,attr-set-boolean-sfa,attr-set-money-sfa,attr-set-date-sfa,attr-set-time-sfa,attr-set-datetime-sfa,attr-set-ref-product-sfa,attr-set-ref-product-type-sfa,attr-set-ref-channel-sfa,attr-set-ref-state-sfa,attr-set-ref-zone-sfa,attr-set-ref-shipping-method-sfa,attr-set-ref-category-sfa,attr-set-ref-review-sfa,attr-set-ref-key-value-sfa';
    const expectedProduct = 'false,false,ImpEx with all types,1,,MONGO_ID,productKey,,,,,,Foo,,foo,,,,';
    const expectedVariant =   ',,,2,variantKey,,,123,,,,,,,,,,,,,,,lenum1,,,,,,,,,,,,,,,,,,,lenum1;lenum2';

    return this.export.exportFull(outputLocation)
    .then(function(result) {
      expect(result).toBe('Export done.');

      try {
        fs.statSync(outputLocation).isFile();
        return Promise.resolve();
      } catch (err) {
        return Promise.reject("Archive was not generated");
      }}).then(function() {
      console.log("Archive was generated successfully");
      return extractArchive(outputLocation, {dir: tempDir.name});}).then(function() {

      let csvFile;
      try {
        const exportedFolder = path.join(tempDir.name, 'products');
        fs.statSync(exportedFolder); // test if file was created
        const files = fs.readdirSync(exportedFolder);
        expect(files.length).toBe(1);
        csvFile = path.join(exportedFolder, files[0]);
        fs.statSync(csvFile); // test if file was created
      } catch (e) {
        return Promise.reject('Archive was not successfully created or parsed');
      }

      return fs.readFileAsync(csvFile, {encoding: 'utf8'});})
    .then(content => {
      const csv = content.split("\n");
      expect(csv.length).toBe(4);

      expect(csv[0]).toBe(expectedHeader);
      expect(csv[2]).toBe(expectedVariant);
      expect(csv[3]).toBe("");

      return this.client.productProjections.staged(true)
      .fetch()
      .then(function(res) {
        expect(res.body.results.length).toBe(1);
        const product = res.body.results[0];

        // replace mongoId
        const expectedProductLine = expectedProduct.replace('MONGO_ID', product.id);
        return expect(csv[1]).toBe(expectedProductLine);
      });
  }).then(() => done()).catch(err => done(_.prettify(err)))
    .finally(() => tempDir.removeCallback());
  });

  it('should export data in different encoding', function(done) {
    const encoding = 'win1250';
    const template =
    `\
productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en,žškřďťň\
`;
    const outputLocation = '/tmp/output.csv';
    const expectedCSV =
    `\
productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en,žškřďťň
${this.productType.name},,1
,,2,Enum1,Enum1;Enum2
\
`;

    // export data in win1250 encoding
    this.export.options.encoding = encoding;
    return this.export.exportDefault(template, outputLocation)
    .then(function(result) {
      expect(result).toBe('Export done.');

      return fs.readFileAsync(outputLocation, {encoding: 'utf8'});})
    .then(function(content) {
      // compare exported data with text encoded in utf8
      expect(content).not.toBe(expectedCSV);

      // decode from win1250 to utf8 and compare with expected result
      const decoded = iconv.decode(fs.readFileSync(outputLocation), encoding);
      expect(decoded).toBe(expectedCSV);

      return done();}).catch(err => done(_.prettify(err)));
  });

  it('should export product with money set attribute', function(done) {
    const testProductType = require('../../data/moneySetAttributeProductType');
    const testProduct = require('../../data/moneySetAttributeProduct');
    const outputLocation = '/tmp/output.csv';
    const template =
    `\
productType,name,variantId,money_attribute,prices\
`;
    const expectedCSV =
    `\
productType,name,variantId,money_attribute,prices
${testProductType.name},,1,EUR 123456;GBP 98765,DE-EUR 12900$2001-09-11T14:00:00.000Z~2015-09-11T14:00:00.000Z
\
`;

    return TestHelpers.setupProductType(this.client, testProductType, testProduct)
    .then(() => {
      return this.export.exportDefault(template, outputLocation);
  }).then(function(result) {
      expect(result).toBe('Export done.');
      return fs.readFileAsync(outputLocation, {encoding: 'utf8'});})
    .then(content => {
      expect(content).toBe(expectedCSV);
      return done();
  }).catch(err => done(_.prettify(err)));
  });


  it('should do a full export with queryString', function(done) {
    const exporter = new Export({
      client: Config,
      export: {
        queryString: 'where=name(en = "Foo")&staged=true',
        isQueryEncoded: false
      }
    });

    const tempDir = tmp.dirSync({ unsafeCleanup: true });
    const outputLocation = path.join(tempDir.name, 'output-querystring.zip');
    const expectedHeader = '_published,_hasStagedChanges,productType,variantId,variantKey,id,key,sku,prices,tax,categories,images,name.en,description.en,slug.en,metaTitle.en,metaDescription.en,metaKeywords.en,searchKeywords.en,attr-text-n,attr-ltext-n.en,attr-enum-n,attr-lenum-n,attr-number-n,attr-boolean-n,attr-money-n,attr-date-n,attr-time-n,attr-datetime-n,attr-ref-product-n,attr-ref-product-type-n,attr-ref-channel-n,attr-ref-state-n,attr-ref-zone-n,attr-ref-shipping-method-n,attr-ref-category-n,attr-ref-review-n,attr-ref-key-value-n,attr-set-text-n,attr-set-ltext-n.en,attr-set-enum-n,attr-set-lenum-n,attr-set-number-n,attr-set-boolean-n,attr-set-money-n,attr-set-date-n,attr-set-time-n,attr-set-datetime-n,attr-set-ref-product-n,attr-set-ref-product-type-n,attr-set-ref-channel-n,attr-set-ref-state-n,attr-set-ref-zone-n,attr-set-ref-shipping-method-n,attr-set-ref-category-n,attr-set-ref-review-n,attr-set-ref-key-value-n,attr-text-u,attr-ltext-u.en,attr-enum-u,attr-lenum-u,attr-number-u,attr-boolean-u,attr-money-u,attr-date-u,attr-time-u,attr-datetime-u,attr-ref-product-u,attr-ref-product-type-u,attr-ref-channel-u,attr-ref-state-u,attr-ref-zone-u,attr-ref-shipping-method-u,attr-ref-category-u,attr-ref-review-u,attr-ref-key-value-u,attr-set-text-u,attr-set-ltext-u.en,attr-set-enum-u,attr-set-lenum-u,attr-set-number-u,attr-set-boolean-u,attr-set-money-u,attr-set-date-u,attr-set-time-u,attr-set-datetime-u,attr-set-ref-product-u,attr-set-ref-product-type-u,attr-set-ref-channel-u,attr-set-ref-state-u,attr-set-ref-zone-u,attr-set-ref-shipping-method-u,attr-set-ref-category-u,attr-set-ref-review-u,attr-set-ref-key-value-u,attr-text-cu,attr-ltext-cu.en,attr-enum-cu,attr-lenum-cu,attr-number-cu,attr-boolean-cu,attr-money-cu,attr-date-cu,attr-time-cu,attr-datetime-cu,attr-ref-product-cu,attr-ref-product-type-cu,attr-ref-channel-cu,attr-ref-state-cu,attr-ref-zone-cu,attr-ref-shipping-method-cu,attr-ref-category-cu,attr-ref-review-cu,attr-ref-key-value-cu,attr-set-text-cu,attr-set-ltext-cu.en,attr-set-enum-cu,attr-set-lenum-cu,attr-set-number-cu,attr-set-boolean-cu,attr-set-money-cu,attr-set-date-cu,attr-set-time-cu,attr-set-datetime-cu,attr-set-ref-product-cu,attr-set-ref-product-type-cu,attr-set-ref-channel-cu,attr-set-ref-state-cu,attr-set-ref-zone-cu,attr-set-ref-shipping-method-cu,attr-set-ref-category-cu,attr-set-ref-review-cu,attr-set-ref-key-value-cu,attr-text-sfa,attr-ltext-sfa.en,attr-enum-sfa,attr-lenum-sfa,attr-number-sfa,attr-boolean-sfa,attr-money-sfa,attr-date-sfa,attr-time-sfa,attr-datetime-sfa,attr-ref-product-sfa,attr-ref-product-type-sfa,attr-ref-channel-sfa,attr-ref-state-sfa,attr-ref-zone-sfa,attr-ref-shipping-method-sfa,attr-ref-category-sfa,attr-ref-review-sfa,attr-ref-key-value-sfa,attr-set-text-sfa,attr-set-ltext-sfa.en,attr-set-enum-sfa,attr-set-lenum-sfa,attr-set-number-sfa,attr-set-boolean-sfa,attr-set-money-sfa,attr-set-date-sfa,attr-set-time-sfa,attr-set-datetime-sfa,attr-set-ref-product-sfa,attr-set-ref-product-type-sfa,attr-set-ref-channel-sfa,attr-set-ref-state-sfa,attr-set-ref-zone-sfa,attr-set-ref-shipping-method-sfa,attr-set-ref-category-sfa,attr-set-ref-review-sfa,attr-set-ref-key-value-sfa';
    const expectedProduct = 'false,false,ImpEx with all types,1,,MONGO_ID,productKey,,,,,,Foo,,foo,,,,';
    const expectedVariant =   ',,,2,variantKey,,,123,,,,,,,,,,,,,,,lenum1,,,,,,,,,,,,,,,,,,,lenum1;lenum2';

    return exporter.exportFull(outputLocation)
      .then(function(result) {
        expect(result).toBe('Export done.');
        try {
          fs.statSync(outputLocation).isFile();
          return Promise.resolve();
        } catch (err) {
          return Promise.reject("Archive was not generated");
        }}).then(function() {
        console.log("Archive was generated successfully");
        return extractArchive(outputLocation, {dir: tempDir.name});}).then(function() {

        let csvFile;
        try {
          const exportedFolder = path.join(tempDir.name, 'products');
          fs.statSync(exportedFolder); // test if file was created
          const files = fs.readdirSync(exportedFolder);
          expect(files.length).toBe(1);
          csvFile = path.join(exportedFolder, files[0]);
          fs.statSync(csvFile); // test if file was created
        } catch (e) {
          return Promise.reject('Archive was not successfully created or parsed');
        }

        return fs.readFileAsync(csvFile, {encoding: 'utf8'});})
      .then(content => {
        const csv = content.split("\n");
        expect(csv.length).toBe(4);

        expect(csv[0]).toBe(expectedHeader);
        expect(csv[2]).toBe(expectedVariant);
        expect(csv[3]).toBe("");

        return this.client.productProjections.staged(true)
        .fetch()
        .then(function(res) {
          expect(res.body.results.length).toBe(1);
          const product = res.body.results[0];

          // replace mongoId
          const expectedProductLine = expectedProduct.replace('MONGO_ID', product.id);
          return expect(csv[1]).toBe(expectedProductLine);
        });
    }).then(() => done()).catch(err => done(_.prettify(err)))
      .finally(() => tempDir.removeCallback());
  });


  it('should do a full export with encoded queryString', function(done) {
    const exporter = new Export({
      client: Config,
      export: {
        queryString: 'where=name(en%20%3D%20%22Foo%22)&staged=true',
        isQueryEncoded: true
      }
    });

    const tempDir = tmp.dirSync({ unsafeCleanup: true });
    const outputLocation = path.join(tempDir.name, 'output-querystring-encoded.zip');
    const expectedHeader = '_published,_hasStagedChanges,productType,variantId,variantKey,id,key,sku,prices,tax,categories,images,name.en,description.en,slug.en,metaTitle.en,metaDescription.en,metaKeywords.en,searchKeywords.en,attr-text-n,attr-ltext-n.en,attr-enum-n,attr-lenum-n,attr-number-n,attr-boolean-n,attr-money-n,attr-date-n,attr-time-n,attr-datetime-n,attr-ref-product-n,attr-ref-product-type-n,attr-ref-channel-n,attr-ref-state-n,attr-ref-zone-n,attr-ref-shipping-method-n,attr-ref-category-n,attr-ref-review-n,attr-ref-key-value-n,attr-set-text-n,attr-set-ltext-n.en,attr-set-enum-n,attr-set-lenum-n,attr-set-number-n,attr-set-boolean-n,attr-set-money-n,attr-set-date-n,attr-set-time-n,attr-set-datetime-n,attr-set-ref-product-n,attr-set-ref-product-type-n,attr-set-ref-channel-n,attr-set-ref-state-n,attr-set-ref-zone-n,attr-set-ref-shipping-method-n,attr-set-ref-category-n,attr-set-ref-review-n,attr-set-ref-key-value-n,attr-text-u,attr-ltext-u.en,attr-enum-u,attr-lenum-u,attr-number-u,attr-boolean-u,attr-money-u,attr-date-u,attr-time-u,attr-datetime-u,attr-ref-product-u,attr-ref-product-type-u,attr-ref-channel-u,attr-ref-state-u,attr-ref-zone-u,attr-ref-shipping-method-u,attr-ref-category-u,attr-ref-review-u,attr-ref-key-value-u,attr-set-text-u,attr-set-ltext-u.en,attr-set-enum-u,attr-set-lenum-u,attr-set-number-u,attr-set-boolean-u,attr-set-money-u,attr-set-date-u,attr-set-time-u,attr-set-datetime-u,attr-set-ref-product-u,attr-set-ref-product-type-u,attr-set-ref-channel-u,attr-set-ref-state-u,attr-set-ref-zone-u,attr-set-ref-shipping-method-u,attr-set-ref-category-u,attr-set-ref-review-u,attr-set-ref-key-value-u,attr-text-cu,attr-ltext-cu.en,attr-enum-cu,attr-lenum-cu,attr-number-cu,attr-boolean-cu,attr-money-cu,attr-date-cu,attr-time-cu,attr-datetime-cu,attr-ref-product-cu,attr-ref-product-type-cu,attr-ref-channel-cu,attr-ref-state-cu,attr-ref-zone-cu,attr-ref-shipping-method-cu,attr-ref-category-cu,attr-ref-review-cu,attr-ref-key-value-cu,attr-set-text-cu,attr-set-ltext-cu.en,attr-set-enum-cu,attr-set-lenum-cu,attr-set-number-cu,attr-set-boolean-cu,attr-set-money-cu,attr-set-date-cu,attr-set-time-cu,attr-set-datetime-cu,attr-set-ref-product-cu,attr-set-ref-product-type-cu,attr-set-ref-channel-cu,attr-set-ref-state-cu,attr-set-ref-zone-cu,attr-set-ref-shipping-method-cu,attr-set-ref-category-cu,attr-set-ref-review-cu,attr-set-ref-key-value-cu,attr-text-sfa,attr-ltext-sfa.en,attr-enum-sfa,attr-lenum-sfa,attr-number-sfa,attr-boolean-sfa,attr-money-sfa,attr-date-sfa,attr-time-sfa,attr-datetime-sfa,attr-ref-product-sfa,attr-ref-product-type-sfa,attr-ref-channel-sfa,attr-ref-state-sfa,attr-ref-zone-sfa,attr-ref-shipping-method-sfa,attr-ref-category-sfa,attr-ref-review-sfa,attr-ref-key-value-sfa,attr-set-text-sfa,attr-set-ltext-sfa.en,attr-set-enum-sfa,attr-set-lenum-sfa,attr-set-number-sfa,attr-set-boolean-sfa,attr-set-money-sfa,attr-set-date-sfa,attr-set-time-sfa,attr-set-datetime-sfa,attr-set-ref-product-sfa,attr-set-ref-product-type-sfa,attr-set-ref-channel-sfa,attr-set-ref-state-sfa,attr-set-ref-zone-sfa,attr-set-ref-shipping-method-sfa,attr-set-ref-category-sfa,attr-set-ref-review-sfa,attr-set-ref-key-value-sfa';
    const expectedProduct = 'false,false,ImpEx with all types,1,,MONGO_ID,productKey,,,,,,Foo,,foo,,,,';
    const expectedVariant =   ',,,2,variantKey,,,123,,,,,,,,,,,,,,,lenum1,,,,,,,,,,,,,,,,,,,lenum1;lenum2';

    return exporter.exportFull(outputLocation)
      .then(function(result) {
        expect(result).toBe('Export done.');
        try {
          fs.statSync(outputLocation).isFile();
          return Promise.resolve();
        } catch (err) {
          return Promise.reject("Archive was not generated");
        }}).then(function() {
        console.log("Archive was generated successfully");
        return extractArchive(outputLocation, {dir: tempDir.name});}).then(function() {

        let csvFile;
        try {
          const exportedFolder = path.join(tempDir.name, 'products');
          fs.statSync(exportedFolder); // test if file was created
          const files = fs.readdirSync(exportedFolder);
          expect(files.length).toBe(1);
          csvFile = path.join(exportedFolder, files[0]);
          fs.statSync(csvFile); // test if file was created
        } catch (e) {
          return Promise.reject('Archive was not successfully created or parsed');
        }

        return fs.readFileAsync(csvFile, {encoding: 'utf8'});})
      .then(content => {
        const csv = content.split("\n");
        expect(csv.length).toBe(4);

        expect(csv[0]).toBe(expectedHeader);
        expect(csv[2]).toBe(expectedVariant);
        expect(csv[3]).toBe("");

        return this.client.productProjections.staged(true)
        .fetch()
        .then(function(res) {
          expect(res.body.results.length).toBe(1);
          const product = res.body.results[0];

          // replace mongoId
          const expectedProductLine = expectedProduct.replace('MONGO_ID', product.id);
          return expect(csv[1]).toBe(expectedProductLine);
        });
    }).then(() => done()).catch(err => done(_.prettify(err)))
      .finally(() => tempDir.removeCallback());
  });

  it('should try to export into unsupported export format', function(done) {
    const exporter = new Export({
      client: Config,
      exportFormat: "unsupported",
    });

    const template =
    `\
productType,name,sku\
`;
    return exporter .exportDefault(template, null)
    .then(() => done('Export should fail!')).catch(function(err) {
      expect(err.message).toBe('Unsupported file type: unsupported, alowed formats are xlsx,csv');
      return done();
    });
  });

  return it('should throw an error when exporting into unsupported encoding', function(done) {
    const template =
    `\
productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en,žškřďťň\
`;
    const outputLocation = '/tmp/output.csv';

    this.export.options.encoding = 'unsupportedEncoding';
    return this.export.exportDefault(template, outputLocation)
    .then(() => done("Should throw an exception with unsupported encoding")).catch(function(err) {
      expect(err.message).toBe("Encoding does not exist: unsupportedEncoding");
      return done();
    });
  });
});
