/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
_.mixin(require('underscore-mixins'));
const Promise = require('bluebird');
const fs = Promise.promisifyAll(require('fs'));
const {Export, Import} = require('../../lib/main');
const Config = require('../../config');
const TestHelpers = require('./testhelpers');

const TEXT_ATTRIBUTE_NONE = 'attr-text-n';
const LTEXT_ATTRIBUTE_COMBINATION_UNIQUE = 'attr-ltext-cu';
const SET_TEXT_ATTRIBUTE_NONE = 'attr-set-text-n';
const BOOLEAN_ATTRIBUTE_NONE = 'attr-boolean-n';

describe('Impex integration tests', function() {

  beforeEach(function(done) {
    jasmine.getEnv().defaultTimeoutInterval = 90000; // 90 sec
    this.importer = new Import(Config);
    this.importer.matchBy = 'slug';
    this.importer.suppressMissingHeaderWarning = true;
    this.exporter = new Export({client: Config});
    this.client = this.importer.client;

    this.productType = TestHelpers.mockProductType();

    return TestHelpers.setupProductType(this.client, this.productType)
    .then(result => {
      this.productType = result;
      return done();
  }).catch(err => done(_.prettify(err.body)))
    .done();
  }
  , 60000); // 60sec

  it('should import and re-export a simple product', function(done) {
    const header = `productType,name.en,slug.en,variantId,sku,prices,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,${TEXT_ATTRIBUTE_NONE},${SET_TEXT_ATTRIBUTE_NONE},${BOOLEAN_ATTRIBUTE_NONE}`;
    const p1 =
      `\
${this.productType.name},myProduct1,my-slug1,1,sku1,FR-EUR 999;CHF 1099,some Text,foo,false
,,,2,sku2,EUR 799,some other Text,foo,\"t1;t2;t3;Üß\"\"Let's see if we support multi
line value\"\"\",true\
`;
    const p2 =
      `\
${this.productType.name},myProduct2,my-slug2,1,sku3,USD 1899,,,,true
,,,2,sku4,USD 1999,,,,false
,,,3,sku5,USD 2099,,,,true
,,,4,sku6,USD 2199,,,,false\
`;
    const csv =
      `\
${header}
${p1}
${p2}\
`;
    this.importer.publishProducts = true;
    return this.importer.import(csv)
    .then(result => {
      console.log("import", result);
      expect(_.size(result)).toBe(2);
      expect(result[0]).toBe('[row 2] New product created.');
      expect(result[1]).toBe('[row 4] New product created.');
      const file = '/tmp/impex.csv';
      return this.exporter.exportDefault(csv, file)
      .then(result => {
        console.log("export", result);
        expect(result).toBe('Export done.');
        return this.client.products.all().fetch();
    }).then(function(res) {
        console.log("products %j", res.body);
        return fs.readFileAsync(file, {encoding: 'utf8'});})
      .then(function(content) {
        console.log("export file content", content);
        expect(content).toMatch(header);
        expect(content).toMatch(p1);
        expect(content).toMatch(p2);
        return done();
      });
  }).catch(err => done(_.prettify(err)));
  });

  return it('should import and re-export SEO attributes', function(done) {
    const header = `productType,variantId,name.en,description.en,slug.en,metaTitle.en,metaDescription.en,metaKeywords.en,${LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,searchKeywords.en`;
    const p1 =
      `\
${this.productType.name},1,seoName,seoDescription,seoSlug,seoMetaTitle,seoMetaDescription,seoMetaKeywords,foo,new;search;keywords
,2,,,,,,,bar\
`;
    const csv =
      `\
${header}
${p1}\
`;
    this.importer.publishProducts = true;
    return this.importer.import(csv)
    .then(result => {
      console.log("import", result);
      expect(_.size(result)).toBe(1);
      expect(result[0]).toBe('[row 2] New product created.');
      const file = '/tmp/impex.csv';
      return this.exporter.exportDefault(header, file)
      .then(function(result) {
        console.log("export", result);
        expect(result).toBe('Export done.');
        return fs.readFileAsync(file, {encoding: 'utf8'});})
      .then(function(content) {
        console.log("export file content", content);
        expect(content).toMatch(header);
        expect(content).toMatch(p1);
        return done();
      });
  }).catch(err => done(_.prettify(err)));
  });
});