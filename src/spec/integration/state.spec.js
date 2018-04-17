/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
_.mixin(require('underscore-mixins'));
const {Import} = require('../../lib/main');
const Config = require('../../config');
const TestHelpers = require('./testhelpers');

const performAllProducts = () => true;

const TEXT_ATTRIBUTE_NONE = 'attr-text-n';

describe('State integration tests', function() {

  beforeEach(function(done) {
    this.importer = new Import(Config);
    this.importer.matchBy = 'sku';
    this.importer.suppressMissingHeaderWarning = true;
    this.client = this.importer.client;

    this.productType = TestHelpers.mockProductType();

    return TestHelpers.setupProductType(this.client, this.productType)
    .then(result => {
      this.productType = result;
      return done();
  }).catch(err => done(_.prettify(err.body)))
    .done();
  }
  , 50000); // 50sec


  it('should publish and unpublish products', function(done) {
    const csv =
      `\
productType,name.en,slug.en,variantId,sku,${TEXT_ATTRIBUTE_NONE}
${this.productType.name},myProduct1,my-slug1,1,sku1,foo
${this.productType.name},myProduct2,my-slug2,1,sku2,bar\
`;
    return this.importer.import(csv)
    .then(result => {
      expect(_.size(result)).toBe(2);
      expect(result[0]).toBe('[row 2] New product created.');
      expect(result[1]).toBe('[row 3] New product created.');
      return this.importer.changeState(true, false, performAllProducts);
  }).then(result => {
      expect(_.size(result)).toBe(2);
      expect(result[0]).toBe('[row 0] Product published.');
      expect(result[1]).toBe('[row 0] Product published.');
      return this.importer.changeState(false, false, performAllProducts);
    }).then(function(result) {
      expect(_.size(result)).toBe(2);
      expect(result[0]).toBe('[row 0] Product unpublished.');
      expect(result[1]).toBe('[row 0] Product unpublished.');
      return done();}).catch(err => done(_.prettify(err)))
    .done();
  }
  , 50000); // 50sec

  it('should only published products with hasStagedChanges', function(done) {
    let csv =
      `\
productType,name.en,slug.en,variantId,sku,${TEXT_ATTRIBUTE_NONE}
${this.productType.name},myProduct1,my-slug1,1,sku1,foo
${this.productType.name},myProduct2,my-slug2,1,sku2,bar\
`;
    return this.importer.import(csv)
    .then(result => {
      expect(_.size(result)).toBe(2);
      expect(result[0]).toBe('[row 2] New product created.');
      expect(result[1]).toBe('[row 3] New product created.');
      return this.importer.changeState(true, false, performAllProducts);
  }).then(result => {
      expect(_.size(result)).toBe(2);
      expect(result[0]).toBe('[row 0] Product published.');
      expect(result[1]).toBe('[row 0] Product published.');
      csv =
        `\
productType,name.en,slug.en,variantId,sku,${TEXT_ATTRIBUTE_NONE}
${this.productType.name},myProduct1,my-slug1,1,sku1,foo
${this.productType.name},myProduct2,my-slug2,1,sku2,baz\
`;
      const im = new Import(Config);
      im.matchBy = 'slug';
      im.suppressMissingHeaderWarning = true;
      return im.import(csv);
    }).then(result => {
      expect(_.size(result)).toBe(2);
      expect(result[0]).toBe('[row 2] Product update not necessary.');
      expect(result[1]).toBe('[row 3] Product updated.');
      return this.importer.changeState(true, false, performAllProducts);
    }).then(function(result) {
      expect(_.size(result)).toBe(2);
      expect(_.contains(result, '[row 0] Product published.')).toBe(true);
      expect(_.contains(result, '[row 0] Product is already published - no staged changes.')).toBe(true);
      return done();}).catch(err => done(_.prettify(err)))
    .done();
  }
  , 50000); // 50sec

  return it('should delete unplublished products', function(done) {
    const csv =
      `\
productType,name.en,slug.en,variantId,sku,${TEXT_ATTRIBUTE_NONE}
${this.productType.name},myProduct1,my-slug1,1,sku1,foo
${this.productType.name},myProduct2,my-slug2,1,sku2,bar\
`;
    return this.importer.import(csv)
    .then(result => {
      expect(_.size(result)).toBe(2);
      expect(result[0]).toBe('[row 2] New product created.');
      expect(result[1]).toBe('[row 3] New product created.');
      return this.importer.changeState(true, true, performAllProducts);
  }).then(function(result) {
      expect(_.size(result)).toBe(2);
      expect(result[0]).toBe('[row 0] Product deleted.');
      expect(result[1]).toBe('[row 0] Product deleted.');
      return done();}).catch(err => done(_.prettify(err)))
    .done();
  }
  , 50000);
}); // 50sec
