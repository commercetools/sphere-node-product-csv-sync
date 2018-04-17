/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
_.mixin(require('underscore-mixins'));
const CONS =  require('../lib/constants');
const {Header, Validator} = require('../lib/main');

describe('Validator', function() {
  beforeEach(function() {
    return this.validator = new Validator();
  });

  describe('@constructor', () =>
    it('should initialize', function() {
      return expect(this.validator).toBeDefined();
    })
  );

  describe('#parse', function() {
    it('should parse string', function(done) {
      return this.validator.parse('foo')
      .then(function(parsed) {
        expect(parsed.count).toBe(1);
        return done();}).catch(err => done(_.prettify(err)));
    });

    it('should store header', function(done) {
      const csv =
        `\
myHeader
row1\
`;
      return this.validator.parse(csv)
      .then(() => {
        expect(this.validator.header).toBeDefined;
        expect(this.validator.header.rawHeader).toEqual(['myHeader']);
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    it('should trim csv cells', function(done) {
      const csv =
        `\
myHeader ,name
row1,name1\
`;
      return this.validator.parse(csv)
      .then(() => {
        expect(this.validator.header).toBeDefined;
        expect(this.validator.header.rawHeader).toEqual(['myHeader', 'name']);
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    return it('should pass everything but the header as content to callback', function(done) {
      const csv =
        `\
myHeader
row1
row2,foo\
`;
      return this.validator.parse(csv)
      .then(function(parsed) {
        expect(parsed.data.length).toBe(2);
        expect(parsed.data[0]).toEqual(['row1']);
        expect(parsed.data[1]).toEqual(['row2', 'foo']);
        return done();}).catch(err => done(_.prettify(err)));
    });
  });

  describe('#checkDelimiters', function() {
    it('should work if all delimiters are different', function() {
      this.validator = new Validator({
        csvDelimiter: '#',
        csvQuote: "'"
      });
      this.validator.checkDelimiters();
      return expect(_.size(this.validator.errors)).toBe(0);
    });

    return it('should produce an error of two delimiters are the same', function() {
      this.validator = new Validator({
        csvDelimiter: ';'});
      this.validator.checkDelimiters();
      expect(_.size(this.validator.errors)).toBe(1);
      const expectedErrorMessage =
        `\
Your selected delimiter clash with each other: {"csvDelimiter":";","csvQuote":"\\"","language":".","multiValue":";","categoryChildren":">"}\
`;
      return expect(this.validator.errors[0]).toBe(expectedErrorMessage);
    });
  });

  describe('#isVariant', function() {
    beforeEach(function() {
      return this.validator.header = new Header(CONS.BASE_HEADERS);
    });

    it('should be true for a variant', function() {
      return expect(this.validator.isVariant(['', '2'], CONS.HEADER_VARIANT_ID)).toBe(true);
    });

    return it('should be false for a product', function() {
      return expect(this.validator.isVariant(['myProduct', '1'])).toBe(false);
    });
  });

  describe('#isProduct', function() {
    beforeEach(function() {
      return this.validator.header = new Header(CONS.BASE_HEADERS);
    });

    return it('should be false for a variantId > 1 with a product type given', function() {
      return expect(this.validator.isProduct(['foo', '2'], CONS.HEADER_VARIANT_ID)).toBe(false);
    });
  });

  describe('#buildProducts', function() {
    beforeEach(function() {});

    it('should build 2 products and their variants', function(done) {
      const csv =
        `\
productType,name,variantId
foo,n1,1
,,2
,,3
bar,n2,1
,,2\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.validator.buildProducts(parsed.data, CONS.HEADER_VARIANT_ID);
        expect(this.validator.errors.length).toBe(0);
        expect(this.validator.rawProducts.length).toBe(2);
        expect(this.validator.rawProducts[0].master).toEqual(['foo', 'n1', '1']);
        expect(this.validator.rawProducts[0].variants.length).toBe(2);
        expect(this.validator.rawProducts[0].startRow).toBe(2);
        expect(this.validator.rawProducts[1].master).toEqual(['bar', 'n2', '1']);
        expect(this.validator.rawProducts[1].variants.length).toBe(1);
        expect(this.validator.rawProducts[1].startRow).toBe(5);
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    it('should return error if row isnt a variant nor product', function(done) {
      const csv =
        `\
productType,name,variantId
myType,,1
,,1
myType,,2
,,foo
,,\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.validator.buildProducts(parsed.data, CONS.HEADER_VARIANT_ID);
        expect(this.validator.errors.length).toBe(3);
        expect(this.validator.errors[0]).toBe('[row 3] Could not be identified as product or variant!');
        expect(this.validator.errors[1]).toBe('[row 5] Could not be identified as product or variant!');
        expect(this.validator.errors[2]).toBe('[row 6] Could not be identified as product or variant!');
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    it('should return error if first row isnt a product row', function(done) {
      const csv =
        `\
productType,name,variantId
foo,,2\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.validator.buildProducts(parsed.data, CONS.HEADER_VARIANT_ID);
        expect(this.validator.errors.length).toBe(1);
        expect(this.validator.errors[0]).toBe('[row 2] We need a product before starting with a variant!');
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    it('should build products without variantId', function(done) {
      const csv =
        `\
productType,sku
foo,123
bar,234
,345
,456\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.validator.buildProducts(parsed.data);
        expect(this.validator.errors.length).toBe(0);
        expect(this.validator.rawProducts.length).toBe(2);
        expect(this.validator.rawProducts[0].master).toEqual(['foo', '123']);
        expect(this.validator.rawProducts[0].variants.length).toBe(0);
        expect(this.validator.rawProducts[0].startRow).toBe(2);
        expect(this.validator.rawProducts[1].master).toEqual(['bar', '234']);
        expect(this.validator.rawProducts[1].variants.length).toBe(2);
        expect(this.validator.rawProducts[1].variants[0].variant).toEqual(['', '345']);
        expect(this.validator.rawProducts[1].variants[1].variant).toEqual(['', '456']);
        expect(this.validator.rawProducts[1].startRow).toBe(3);
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    // TODO: deprecated test. should be updated
    xit('should build products per product type - sku update', function(done) {
      const csv =
        `\
productType,sku
foo,123
bar,234
bar,345
foo,456\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.validator.updateVariantsOnly = true;
        this.validator.buildProducts(parsed.data);
        expect(this.validator.errors.length).toBe(0);
        expect(this.validator.rawProducts.length).toBe(2);
        expect(this.validator.rawProducts[0].variants.length).toBe(2);
        expect(this.validator.rawProducts[0].startRow).toBe(2);
        expect(this.validator.rawProducts[0].variants[0].variant).toEqual(['foo', '123']);
        expect(this.validator.rawProducts[0].variants[0].rowIndex).toBe(2);
        expect(this.validator.rawProducts[0].variants[1].variant).toEqual(['foo', '456']);
        expect(this.validator.rawProducts[0].variants[1].rowIndex).toBe(5);
        expect(this.validator.rawProducts[1].variants.length).toBe(2);
        expect(this.validator.rawProducts[1].variants[0].variant).toEqual(['bar', '234']);
        expect(this.validator.rawProducts[1].variants[0].rowIndex).toBe(3);
        expect(this.validator.rawProducts[1].variants[1].variant).toEqual(['bar', '345']);
        expect(this.validator.rawProducts[1].variants[1].rowIndex).toBe(4);
        expect(this.validator.rawProducts[1].startRow).toBe(3);
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    return it('should use a previous productType if it is missing when doing sku update', function(done) {
      const csv =
        `\
productType,sku
foo,123
bar,234
,345
foo,456\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.validator.updateVariantsOnly = true;
        this.validator.buildProducts(parsed.data);
        expect(this.validator.errors.length).toBe(0);
        expect(_.size(this.validator.rawProducts)).toBe(4);
        expect(this.validator.rawProducts[2].master).toEqual(["bar", "345"]);
        return done();
    }).catch(err => done(_.prettify(err)));
    });
  });

  xdescribe('#valProduct', () =>
    it('should return no error', function(done) {
      const csv =
        `\
productType,name,variantId
foo,bar,bla\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.validator.valProduct(parsed.data);
        return done();
    }).catch(err => done(_.prettify(err)));
    })
  );

  return describe('#validateOffline', () =>
    it('should return no error', function(done) {
      const csv =
        `\
productType,name,variantId
foo,bar,1\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.validator.validateOffline(parsed.data);
        expect(this.validator.errors).toEqual([]);
        return done();
    }).catch(err => done(_.prettify(err)));
    })
  );
});
