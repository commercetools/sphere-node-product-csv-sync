/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
_.mixin(require('underscore-mixins'));
const CONS = require('../lib/constants');
const {Header, Validator} = require('../lib/main');

describe('Header', function() {
  beforeEach(function() {
    return this.validator = new Validator();
  });

  describe('#constructor', function() {
    it('should initialize', () => expect(() => new Header()).toBeDefined());

    return it('should initialize rawHeader', function() {
      const header = new Header(['name']);
      return expect(header.rawHeader).toEqual(['name']);
  });
});

  describe('#validate', function() {
    it('should return error for each missing header', function(done) {
      const csv =
        `\
foo,sku
1,2\
`;
      return this.validator.parse(csv)
      .then(() => {
        const errors = this.validator.header.validate();
        expect(errors.length).toBe(1);
        expect(errors[0]).toBe("Can't find necessary base header 'productType'!");
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    it('should return error when no sku and not variantId header', function(done) {
      const csv =
        `\
foo,productType
1,2\
`;
      return this.validator.parse(csv)
      .then(() => {
        const errors = this.validator.header.validate();
        expect(errors.length).toBe(1);
        expect(errors[0]).toBe("You need either the column 'variantId' or 'sku' to identify your variants!");
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    return it('should return error on duplicate header', function(done) {
      const csv =
        `\
productType,name,variantId,name
1,2,3,4\
`;
      return this.validator.parse(csv)
      .then(() => {
        const errors = this.validator.header.validate();
        expect(errors.length).toBe(1);
        expect(errors[0]).toBe("There are duplicate header entries!");
        return done();
    }).catch(err => done(_.prettify(err)));
    });
  });

  describe('#toIndex', () =>
    it('should create mapping', function(done) {
      const csv =
        `\
productType,foo,variantId
1,2,3\
`;
      return this.validator.parse(csv)
      .then(() => {
        const h2i = this.validator.header.toIndex();
        expect(_.size(h2i)).toBe(3);
        expect(h2i['productType']).toBe(0);
        expect(h2i['foo']).toBe(1);
        expect(h2i['variantId']).toBe(2);
        return done();
    }).catch(err => done(_.prettify(err)));
    })
  );

  describe('#_productTypeLanguageIndexes', function() {
    beforeEach(function() {
      this.productType = {
        id: '213',
        attributes: [{
          name: 'foo',
          type: {
            name: 'ltext'
          }
        }
        ]
      };
      return this.csv =
        `\
someHeader,foo.en,foo.de\
`;
    });
    it('should create language header index for ltext attributes', function(done) {
      return this.validator.parse(this.csv)
      .then(() => {
        const langH2i = this.validator.header._productTypeLanguageIndexes(this.productType);
        expect(_.size(langH2i)).toBe(1);
        expect(_.size(langH2i['foo'])).toBe(2);
        expect(langH2i['foo']['de']).toBe(2);
        expect(langH2i['foo']['en']).toBe(1);
        return done();
    }).catch(err => done(_.prettify(err)));
    });

    return it('should provide access via productType', function(done) {
      return this.validator.parse(this.csv)
      .then(() => {
        const expected = {
          de: 2,
          en: 1
        };
        expect(this.validator.header.productTypeAttributeToIndex(this.productType, this.productType.attributes[0])).toEqual(expected);
        return done();
    }).catch(err => done(_.prettify(err)));
    });
  });

  describe('#_languageToIndex', () =>
    it('should create mapping for language attributes', function(done) {
      const csv =
        `\
foo,a1.de,bar,a1.it\
`;
      return this.validator.parse(csv)
      .then(() => {
        const langH2i = this.validator.header._languageToIndex(['a1']);
        expect(_.size(langH2i)).toBe(1);
        expect(_.size(langH2i['a1'])).toBe(2);
        expect(langH2i['a1']['de']).toBe(1);
        expect(langH2i['a1']['it']).toBe(3);
        return done();
    }).catch(err => done(_.prettify(err)));
    })
  );

  return describe('#missingHeaderForProductType', () =>
    it('should give list of attributes that are not covered by headers', function(done) {
      const csv =
        `\
foo,a1.de,bar,a1.it\
`;
      const productType = {
        id: 'whatAtype',
        attributes: [
          { name: 'foo', type: { name: 'text' } },
          { name: 'bar', type: { name: 'enum' } },
          { name: 'a1', type: { name: 'ltext' } },
          { name: 'a2', type: { name: 'set' } }
        ]
      };
      return this.validator.parse(csv)
      .then(() => {
        const { header } = this.validator;
        header.toIndex();
        header.toLanguageIndex();
        const missingHeaders = header.missingHeaderForProductType(productType);
        expect(_.size(missingHeaders)).toBe(1);
        expect(missingHeaders[0]).toEqual({ name: 'a2', type: { name: 'set' } });
        return done();
    }).catch(err => done(_.prettify(err)));
    })
  );
});
