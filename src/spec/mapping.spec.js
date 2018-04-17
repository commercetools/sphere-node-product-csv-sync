/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const CONS = require('../lib/constants');
const {Header, Mapping, Validator} = require('../lib/main');
let Categories = require('../lib/categories');

// API Types
const Types = require('../lib/types');
Categories = require('../lib/categories');
const CustomerGroups = require('../lib/customergroups');
const Taxes = require('../lib/taxes');
const Channels = require('../lib/channels');

describe('Mapping', function() {
  beforeEach(function() {
    const options = {
      types : new Types(),
      customerGroups : new CustomerGroups(),
      categories : new Categories(),
      taxes : new Taxes(),
      channels : new Channels(),
    };
    this.validator = new Validator(options);
    return this.map = new Mapping(options);
  });

  describe('#constructor', () =>
    it('should initialize', function() {
      expect(() => new Mapping()).toBeDefined();
      return expect(this.map).toBeDefined();
    })
  );

  describe('#isValidValue', function() {
    it('should return false for undefined and null', function() {
      expect(this.map.isValidValue(undefined)).toBe(false);
      return expect(this.map.isValidValue(null)).toBe(false);
    });
    it('should return false for empty string', function() {
      expect(this.map.isValidValue('')).toBe(false);
      return expect(this.map.isValidValue("")).toBe(false);
    });
    return it('should return true for strings with length > 0', function() {
      return expect(this.map.isValidValue("foo")).toBe(true);
    });
  });

  describe('#ensureValidSlug', function() {
    it('should accept unique slug', function() {
      return expect(this.map.ensureValidSlug('foo')).toBe('foo');
    });

    it('should enhance duplicate slug', function() {
      expect(this.map.ensureValidSlug('foo')).toBe('foo');
      return expect(this.map.ensureValidSlug('foo')).toMatch(/foo\d{5}/);
    });

    it('should fail for undefined or null', function() {
      expect(this.map.ensureValidSlug(undefined, 99)).toBeUndefined();
      expect(this.map.errors[0]).toBe("[row 99:slug] Can't generate valid slug out of 'undefined'!");

      expect(this.map.ensureValidSlug(null, 3)).toBeUndefined();
      return expect(this.map.errors[1]).toBe("[row 3:slug] Can't generate valid slug out of 'null'!");
    });

    return it('should fail for too short slug', function() {
      expect(this.map.ensureValidSlug('1', 7)).toBeUndefined();
      expect(_.size(this.map.errors)).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 7:slug] Can't generate valid slug out of '1'!");
    });
  });

  describe('#mapLocalizedAttrib', function() {
    it('should create mapping for language attributes', function(done) {
      const csv =
        `\
foo,name.de,bar,name.it
x,Hallo,y,ciao\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        const values = this.map.mapLocalizedAttrib(parsed.data[0], CONS.HEADER_NAME, this.validator.header.toLanguageIndex());
        expect(_.size(values)).toBe(2);
        expect(values['de']).toBe('Hallo');
        expect(values['it']).toBe('ciao');
        return done();
    }).catch(done);
    });

    it('should fallback to non localized column', function(done) {
      const csv =
        `\
foo,a1,bar
x,hi,y
aaa,,bbb\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.header.toIndex();
        let values = this.map.mapLocalizedAttrib(parsed.data[0], 'a1', {});
        expect(_.size(values)).toBe(1);
        expect(values['en']).toBe('hi');

        values = this.map.mapLocalizedAttrib(parsed.data[1], 'a1', {});
        expect(values).toBeUndefined();
        return done();
    }).catch(done);
    });

    return it('should return undefined if header can not be found', function(done) {
      const csv =
        `\
foo,a1,bar
x,hi,y\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.header.toIndex();
        const values = this.map.mapLocalizedAttrib(parsed.data[0], 'a2', {});
        expect(values).toBeUndefined();
        return done();
    }).catch(done);
    });
  });

  describe('#mapBaseProduct', function() {
    it('should map base product', function(done) {
      const csv =
        `\
productType,id,name,variantId,key
foo,xyz,myProduct,1,key123\
`;
      const pt =
        {id: '123'};
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.validateOffline(parsed.data);
        const product = this.map.mapBaseProduct(this.validator.rawProducts[0].master, pt);

        const expectedProduct = {
          id: 'xyz',
          key: 'key123',
          productType: {
            typeId: 'product-type',
            id: '123'
          },
          name: {
            en: 'myProduct'
          },
          slug: {
            en: 'myproduct'
          },
          masterVariant: {},
          categoryOrderHints: {},
          variants: [],
          categories: []
        };

        expect(product).toEqual(expectedProduct);
        return done();
    }).catch(done);
    });

    it('should map base product with categories', function(done) {
      const csv =
        `\
productType,id,name,variantId,categories
foo,xyz,myProduct,1,ext-123\
`;
      const pt =
        {id: '123'};
      const cts = [{
        id: '234',
        name: {
          en: 'mockName'
        },
        slug: {
          en: 'mockSlug'
        },
        externalId: 'ext-123'
      }
      ];

      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.categories = new Categories;
        this.categories.buildMaps(cts);
        this.map.categories = this.categories;
        this.validator.validateOffline(parsed.data);
        const product = this.map.mapBaseProduct(this.validator.rawProducts[0].master, pt);

        const expectedProduct = {
          id: 'xyz',
          productType: {
            typeId: 'product-type',
            id: '123'
          },
          name: {
            en: 'myProduct'
          },
          slug: {
            en: 'myproduct'
          },
          masterVariant: {},
          categoryOrderHints: {},
          variants: [],
          categories: [{
            typeId: 'category',
            id: '234'
          }
          ]
        };

        expect(product).toEqual(expectedProduct);
        return done();
    }).catch(done);
    });
    it('should map search keywords', function(done) {
      const csv =
      `\
productType,variantId,id,name.en,slug.en,searchKeywords.en,searchKeywords.fr-FR
product-type,1,xyz,myProduct,myproduct,some;new;search;keywords,bruxelle;liege;brugge,\
`;
      const pt =
        {id: '123'};
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.validateOffline(parsed.data);
        const product = this.map.mapBaseProduct(this.validator.rawProducts[0].master, pt);

        const expectedProduct = {
          id: 'xyz',
          productType: {
            typeId: 'product-type',
            id: '123'
          },
          name: {
            en: 'myProduct'
          },
          slug: {
            en: 'myproduct'
          },
          masterVariant: {},
          categoryOrderHints: {},
          variants: [],
          categories: [],
          searchKeywords: {"en":[{"text":"some"},{"text":"new"},{"text":"search"},{"text":"keywords"}],"fr-FR":[{"text":"bruxelle"},{"text":"liege"},{"text":"brugge"}]}
        };

        expect(product).toEqual(expectedProduct);
        return done();
    }).catch(done);
    });

    return it('should map empty search keywords', function(done) {
      const csv =
        `\
productType,variantId,id,name.en,slug.en,searchKeywords.en
product-type,1,xyz,myProduct,myproduct,\
`;
      const pt =
        {id: '123'};
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.validateOffline(parsed.data);
        const product = this.map.mapBaseProduct(this.validator.rawProducts[0].master, pt);

        const expectedProduct = {
          id: 'xyz',
          productType: {
            typeId: 'product-type',
            id: '123'
          },
          name: {
            en: 'myProduct'
          },
          slug: {
            en: 'myproduct'
          },
          masterVariant: {},
          categoryOrderHints: {},
          variants: [],
          categories: []
        };

        expect(product).toEqual(expectedProduct);
        return done();
    }).catch(done);
    });
  });

  describe('#mapVariant', function() {
    it('should give feedback on bad variant id', function() {
      this.map.header = new Header([ 'variantId' ]);
      this.map.header.toIndex();
      const variant = this.map.mapVariant([ 'foo' ], 3, null, 7);
      expect(variant).toBeUndefined();
      expect(_.size(this.map.errors)).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 7:variantId] The number 'foo' isn't valid!");
    });

    it('should map variant with one attribute', function() {
      const productType = {
        attributes: [
          { name: 'a2', type: { name: 'text' } }
        ]
      };

      this.map.header = new Header([ 'a0', 'a1', 'a2', 'sku', 'variantId', 'variantKey' ]);
      this.map.header.toIndex();
      const variant = this.map.mapVariant([ 'v0', 'v1', 'v2', 'mySKU', '9', 'vKey123' ], 9, productType, 77);

      const expectedVariant = {
        id: 9,
        sku: 'mySKU',
        key: 'vKey123',
        prices: [],
        attributes: [{
          name: 'a2',
          value: 'v2'
        }
        ],
        images: []
      };

      return expect(variant).toEqual(expectedVariant);
    });

    return it('should take over SameForAll contrainted attribute from master row', function() {
      this.map.header = new Header([ 'aSame', 'variantId' ]);
      this.map.header.toIndex();
      const productType = {
        attributes: [
          { name: 'aSame', type: { name: 'text' }, attributeConstraint: 'SameForAll' }
        ]
      };
      const product = {
        masterVariant: {
          attributes: [
            { name: 'aSame', value: 'sameValue' }
          ]
        }
      };

      const variant = this.map.mapVariant([ 'whatever', '11' ], 11, productType, 99, product);

      const expectedVariant = {
        id: 11,
        prices: [],
        attributes: [{
          name: 'aSame',
          value: 'sameValue'
        }
        ],
        images: []
      };

      return expect(variant).toEqual(expectedVariant);
    });
  });

  describe('#mapAttribute', function() {
    it('should map simple text attribute', function() {
      const productTypeAttribute = {
        name: 'foo',
        type: {
          name: 'text'
        }
      };
      this.map.header = new Header([ 'foo', 'bar' ]);
      const attribute = this.map.mapAttribute([ 'some text', 'blabla' ], productTypeAttribute);

      const expectedAttribute = {
        name: 'foo',
        value: 'some text'
      };
      return expect(attribute).toEqual(expectedAttribute);
    });

    it('should map ltext attribute', function() {
      const productType = {
        id: 'myType',
        attributes: [{
          name: 'bar',
          type: {
            name: 'ltext'
          }
        }
        ]
      };
      this.map.header = new Header([ 'foo', 'bar.en', 'bar.es' ]);
      const languageHeader2Index = this.map.header._productTypeLanguageIndexes(productType);
      const attribute = this.map.mapAttribute([ 'some text', 'hi', 'hola' ], productType.attributes[0], languageHeader2Index);

      const expectedAttribute = {
        name: 'bar',
        value: {
          en: 'hi',
          es: 'hola'
        }
      };
      return expect(attribute).toEqual(expectedAttribute);
    });

    it('should map set of lext attribute', function() {
      const productType = {
        id: 'myType',
        attributes: [{
          name: 'baz',
          type: {
            name: 'set',
            elementType: {
              name: 'ltext'
            }
          }
        }
        ]
      };
      this.map.header = new Header([ 'foo', 'baz.en', 'baz.de' ]);
      const languageHeader2Index = this.map.header._productTypeLanguageIndexes(productType);
      const attribute = this.map.mapAttribute([ 'some text', 'foo1;foo2', 'barA;barB;barC' ], productType.attributes[0], languageHeader2Index);

      const expectedAttribute = {
        name: 'baz',
        value: [
          {"en": "foo1", "de": "barA"},
          {"en": "foo2", "de": "barB"},
          {"de": "barC"}
        ]
      };
      return expect(attribute).toEqual(expectedAttribute);
    });

    it('should map set of money attributes', function() {
      const productType = {
        id: 'myType',
        attributes: [{
          name: 'money-rules',
          type: {
            name: 'set',
            elementType: {
              name: 'money'
            }
          }
        }
        ]
      };
      this.map.header = new Header([ 'money-rules' ]);
      const languageHeader2Index = this.map.header._productTypeLanguageIndexes(productType);
      const attribute = this.map.mapAttribute([ 'EUR 200;USD 100' ], productType.attributes[0], languageHeader2Index);

      const expectedAttribute = {
        name: 'money-rules',
        value: [
          {"centAmount": 200, "currencyCode": "EUR"},
          {"centAmount": 100, "currencyCode": "USD"}
        ]
      };
      return expect(attribute).toEqual(expectedAttribute);
    });

    it('should map set of number attributes', function() {
      const productType = {
        id: 'myType',
        attributes: [{
          name: 'numbers',
          type: {
            name: 'set',
            elementType: {
              name: 'number'
            }
          }
        }
        ]
      };
      this.map.header = new Header([ 'numbers' ]);
      const languageHeader2Index = this.map.header._productTypeLanguageIndexes(productType);
      const attribute = this.map.mapAttribute([ '1;0;-1' ], productType.attributes[0], languageHeader2Index);

      const expectedAttribute = {
        name: 'numbers',
        value: [ 1, 0, -1 ]
      };
      return expect(attribute).toEqual(expectedAttribute);
    });

    it('should validate attribute value (undefined)', function() {
      const productTypeAttribute = {
        name: 'foo',
        type: {
          name: 'text'
        }
      };
      this.map.header = new Header([ 'foo', 'bar' ]);
      const attribute = this.map.mapAttribute([ undefined, 'blabla' ], productTypeAttribute);

      return expect(attribute).not.toBeDefined();
    });

    it('should validate attribute value (empty object)', function() {
      const productTypeAttribute = {
        name: 'foo',
        type: {
          name: 'text'
        }
      };
      this.map.header = new Header([ 'foo', 'bar' ]);
      const attribute = this.map.mapAttribute([ {}, 'blabla' ], productTypeAttribute);

      return expect(attribute).not.toBeDefined();
    });

    return it('should validate attribute value (empty string)', function() {
      const productTypeAttribute = {
        name: 'foo',
        type: {
          name: 'text'
        }
      };
      this.map.header = new Header([ 'foo', 'bar' ]);
      const attribute = this.map.mapAttribute([ '', 'blabla' ], productTypeAttribute);

      return expect(attribute).not.toBeDefined();
    });
  });

  describe('#mapPrices', function() {
    it('should map single simple price', function() {
      const prices = this.map.mapPrices('EUR 999');
      expect(prices.length).toBe(1);
      const expectedPrice = {
        value: {
          centAmount: 999,
          currencyCode: 'EUR'
        }
      };
      return expect(prices[0]).toEqual(expectedPrice);
    });

    it('should give feedback when number part is not a number', function() {
      const prices = this.map.mapPrices('EUR 9.99', 7);
      expect(prices.length).toBe(0);
      expect(this.map.errors.length).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 7:prices] Can not parse price 'EUR 9.99'!");
    });

    it('should give feedback when when currency and amount isnt proper separated', function() {
      const prices = this.map.mapPrices('EUR1', 8);
      expect(prices.length).toBe(0);
      expect(this.map.errors.length).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 8:prices] Can not parse price 'EUR1'!");
    });

    it('should map price with country', function() {
      const prices = this.map.mapPrices('CH-EUR 700');
      expect(prices.length).toBe(1);
      const expectedPrice = {
        value: {
          centAmount: 700,
          currencyCode: 'EUR'
        },
        country: 'CH'
      };
      return expect(prices[0]).toEqual(expectedPrice);
    });

    it('should give feedback when there are problems in parsing the country info ', function() {
      const prices = this.map.mapPrices('CH-DE-EUR 700', 99);
      expect(prices.length).toBe(0);
      expect(this.map.errors.length).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 99:prices] Can not parse price 'CH-DE-EUR 700'!");
    });

    it('should map price with customer group', function() {
      this.map.customerGroups = {
        name2id: {
          'my Group 7': 'group123'
        }
      };
      const prices = this.map.mapPrices('GBP 0 my Group 7');
      expect(prices.length).toBe(1);
      const expectedPrice = {
        value: {
          centAmount: 0,
          currencyCode: 'GBP'
        },
        customerGroup: {
          typeId: 'customer-group',
          id: 'group123'
        }
      };
      return expect(prices[0]).toEqual(expectedPrice);
    });

    it('should map price with validFrom', function() {
      const prices = this.map.mapPrices('EUR 234$2001-09-11T14:00:00.000Z');
      expect(prices.length).toBe(1);
      const expectedPrice = {
        validFrom: '2001-09-11T14:00:00.000Z',
        value: {
          centAmount: 234,
          currencyCode: 'EUR'
        }
      };
      return expect(prices[0]).toEqual(expectedPrice);
    });

    it('should map price with validUntil', function() {
      const prices = this.map.mapPrices('EUR 1123~2001-09-11T14:00:00.000Z');
      expect(prices.length).toBe(1);
      const expectedPrice = {
        validUntil: '2001-09-11T14:00:00.000Z',
        value: {
          centAmount: 1123,
          currencyCode: 'EUR'
        }
      };
      return expect(prices[0]).toEqual(expectedPrice);
    });

    it('should map price with validFrom and validUntil', function() {
      const prices = this.map.mapPrices('EUR 6352$2001-09-11T14:00:00.000Z~2015-09-11T14:00:00.000Z');
      expect(prices.length).toBe(1);
      const expectedPrice = {
        validFrom: '2001-09-11T14:00:00.000Z',
        validUntil: '2015-09-11T14:00:00.000Z',
        value: {
          centAmount: 6352,
          currencyCode: 'EUR'
        }
      };
      return expect(prices[0]).toEqual(expectedPrice);
    });

    it('should give feedback that customer group does not exist', function() {
      const prices = this.map.mapPrices('YEN 777 unknownGroup', 5);
      expect(prices.length).toBe(0);
      expect(this.map.errors.length).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 5:prices] Can not find customer group 'unknownGroup'!");
    });

    it('should map price with channel', function() {
      this.map.channels = {
        key2id: {
          retailerA: 'channelId123'
        }
      };
      const prices = this.map.mapPrices('YEN 19999#retailerA;USD 1 #retailerA', 1234);
      expect(prices.length).toBe(2);
      expect(this.map.errors.length).toBe(0);
      let expectedPrice = {
        value: {
          centAmount: 19999,
          currencyCode: 'YEN'
        },
        channel: {
          typeId: 'channel',
          id: 'channelId123'
        }
      };
      expect(prices[0]).toEqual(expectedPrice);
      expectedPrice = {
        value: {
          centAmount: 1,
          currencyCode: 'USD'
        },
        channel: {
          typeId: 'channel',
          id: 'channelId123'
        }
      };
      return expect(prices[1]).toEqual(expectedPrice);
    });

    it('should give feedback that channel with key does not exist', function() {
      const prices = this.map.mapPrices('YEN 777 #nonExistingChannelKey', 42);
      expect(prices.length).toBe(0);
      expect(this.map.errors.length).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 42:prices] Can not find channel with key 'nonExistingChannelKey'!");
    });

    it('should map price with customer group and channel', function() {
      this.map.customerGroups = {
        name2id: {
          b2bCustomer: 'group_123'
        }
      };
      this.map.channels = {
        key2id: {
          'ware House-42': 'dwh_987'
        }
      };
      const prices = this.map.mapPrices('DE-EUR 100 b2bCustomer#ware House-42');
      expect(prices.length).toBe(1);
      const expectedPrice = {
        value: {
          centAmount: 100,
          currencyCode: 'EUR'
        },
        country: 'DE',
        channel: {
          typeId: 'channel',
          id: 'dwh_987'
        },
        customerGroup: {
          typeId: 'customer-group',
          id: 'group_123'
        }
      };
      return expect(prices[0]).toEqual(expectedPrice);
    });

    return it('should map multiple prices', function() {
      const prices = this.map.mapPrices('EUR 100;UK-USD 200;YEN -999');
      expect(prices.length).toBe(3);
      let expectedPrice = {
        value: {
          centAmount: 100,
          currencyCode: 'EUR'
        }
      };
      expect(prices[0]).toEqual(expectedPrice);
      expectedPrice = {
        value: {
          centAmount: 200,
          currencyCode: 'USD'
        },
        country: 'UK'
      };
      expect(prices[1]).toEqual(expectedPrice);
      expectedPrice = {
        value: {
          centAmount: -999,
          currencyCode: 'YEN'
        }
      };
      return expect(prices[2]).toEqual(expectedPrice);
    });
  });

  describe('#mapNumber', function() {
    it('should map integer', function() {
      return expect(this.map.mapNumber('0')).toBe(0);
    });

    it('should map negative integer', function() {
      return expect(this.map.mapNumber('-100')).toBe(-100);
    });

    it('should map float', function() {
      return expect(this.map.mapNumber('0.99')).toBe(0.99);
    });

    it('should map negative float', function() {
      return expect(this.map.mapNumber('-13.3333')).toBe(-13.3333);
    });

    return it('should fail when input is not a valid number', function() {
      const number = this.map.mapNumber('-10e5', 'myAttrib', 4);
      expect(number).toBeUndefined();
      expect(this.map.errors.length).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 4:myAttrib] The number '-10e5' isn't valid!");
    });
  });

  describe('#mapInteger', function() {
    it('should map integer', function() {
      return expect(this.map.mapInteger('11')).toBe(11);
    });

    return it('should not map floats', function() {
      const number = this.map.mapInteger('-0.1', 'foo', 7);
      expect(this.map.errors.length).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 7:foo] The number '-0.1' isn't valid!");
    });
  });

  describe('#mapBoolean', function() {
    it('should map true', function() {
      return expect(this.map.mapBoolean('true')).toBe(true);
    });

    it('should map true represented as a number', function() {
      return expect(this.map.mapBoolean('1')).toBe(true);
    });

    it('should map false represented as a number', function() {
      return expect(this.map.mapBoolean('0')).toBe(false);
    });

    it('should not map invalid number as a boolean', function() {
      expect(this.map.mapBoolean('12345', 'myAttrib', '4')).toBe(undefined);
      expect(this.map.errors.length).toBe(1);
      return expect(this.map.errors[0]).toBe("[row 4:myAttrib] The value '12345' isn't a valid boolean!");
    });

    it('should map case insensitive', function() {
      expect(this.map.mapBoolean('false')).toBe(false);
      expect(this.map.mapBoolean('False')).toBe(false);
      return expect(this.map.mapBoolean('False')).toBe(false);
    });

    it('should map the empty string', function() {
      return expect(this.map.mapBoolean('')).toBeUndefined();
    });

    return it('should map undefined', function() {
      return expect(this.map.mapBoolean()).toBeUndefined();
    });
  });

  describe('#mapReference', () =>
    it('should map a single reference', function() {
      const attribute = {
        type: {
          referenceTypeId: 'product'
        }
      };
      return expect(this.map.mapReference('123-456', attribute)).toEqual({ id: '123-456', typeId: 'product' });
  })
);

  describe('#mapProduct', () =>
    it('should map a product', function(done) {
      const productType = {
        id: 'myType',
        attributes: []
      };
      const csv =
        `\
productType,name,variantId,sku
foo,myProduct,1,x
,,2,y
,,3,z\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.validateOffline(parsed.data);
        const data = this.map.mapProduct(this.validator.rawProducts[0], productType);

        const expectedProduct = {
          productType: {
            typeId: 'product-type',
            id: 'myType'
          },
          name: {
            en: 'myProduct'
          },
          slug: {
            en: 'myproduct'
          },
          categories: [],
          masterVariant: {
            id: 1,
            sku: 'x',
            prices: [],
            attributes: [],
            images: []
          },
          categoryOrderHints: {},
          variants: [
            { id: 2, sku: 'y', prices: [], attributes: [], images: [] },
            { id: 3, sku: 'z', prices: [], attributes: [], images: [] }
          ]
        };

        expect(data.product).toEqual(expectedProduct);
        return done();
    }).catch(done);
    })
  );

  return describe('#mapCategoryOrderHints', function() {

    beforeEach(function() {

      this.exampleCategory = {
        id: 'categoryId',
        name: {
          en: 'myCoolCategory'
        },
        slug: {
          en: 'slug-123'
        },
        externalId: 'myExternalId'
      };
      // mock the categories
      this.map.categories.buildMaps([
          this.exampleCategory
        ]);
      this.productType = {
        id: 'myType',
        attributes: []
      };

      return this.expectedProduct = {
        productType: {
          typeId: 'product-type',
          id: 'myType'
        },
        name: {
          en: 'myProduct'
        },
        slug: {
          en: 'myproduct'
        },
        categories: [],
        categoryOrderHints: {
          categoryId: '0.9'
        },
        masterVariant: {
          id: 1,
          sku: 'x',
          prices: [],
          attributes: [],
          images: []
        },
        variants: []
      };});

    it('should should map the categoryOrderHints using a category id', function(done) {
      const csv =
        `\
productType,name,variantId,sku,categoryOrderHints
foo,myProduct,1,x,${this.exampleCategory.id}:0.9\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.validateOffline(parsed.data);
        const data = this.map.mapProduct(this.validator.rawProducts[0], this.productType);

        expect(data.product).toEqual(this.expectedProduct);
        return done();
    }).catch(done);
    });

    it('should should map the categoryOrderHints using a category name', function(done) {
      const csv =
        `\
productType,name,variantId,sku,categoryOrderHints
foo,myProduct,1,x,${this.exampleCategory.name.en}:0.9\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.validateOffline(parsed.data);
        const data = this.map.mapProduct(this.validator.rawProducts[0], this.productType);

        expect(data.product).toEqual(this.expectedProduct);
        return done();
    }).catch(done);
    });

    it('should should map the categoryOrderHints using a category slug', function(done) {
      const csv =
        `\
productType,name,variantId,sku,categoryOrderHints
foo,myProduct,1,x,${this.exampleCategory.slug.en}:0.9\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.validateOffline(parsed.data);
        const data = this.map.mapProduct(this.validator.rawProducts[0], this.productType);

        expect(data.product).toEqual(this.expectedProduct);
        return done();
    }).catch(done);
    });

    return it('should should map the categoryOrderHints using a category externalId', function(done) {
      const csv =
        `\
productType,name,variantId,sku,categoryOrderHints
foo,myProduct,1,x,${this.exampleCategory.externalId}:0.9\
`;
      return this.validator.parse(csv)
      .then(parsed => {
        this.map.header = parsed.header;
        this.validator.validateOffline(parsed.data);
        const data = this.map.mapProduct(this.validator.rawProducts[0], this.productType);

        expect(data.product).toEqual(this.expectedProduct);
        return done();
    }).catch(done);
    });
  });
});
