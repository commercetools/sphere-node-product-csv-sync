/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const Types = require('../lib/types');
const CONS = require('../lib/constants');
const {ExportMapping, Header, Categories} = require('../lib/main');

describe('ExportMapping', function() {

  beforeEach(function() {
    return this.exportMapping = new ExportMapping();
  });

  describe('#constructor', () =>
    it('should initialize', function() {
      return expect(this.exportMapping).toBeDefined();
    })
  );

  describe('#mapPrices', function() {
    beforeEach(function() {
      this.exportMapping.channelService =
        {id2key: {}};
      return this.exportMapping.customerGroupService =
        {id2name: {}};});
    it('should map simple price', function() {
      const prices = [
        { value: { centAmount: 999, currencyCode: 'EUR' } }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('EUR 999');
    });

    it('should map price with country', function() {
      const prices = [
        { value: { centAmount: 77, currencyCode: 'EUR' }, country: 'DE' }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('DE-EUR 77');
    });

    it('should map multiple prices', function() {
      const prices = [
        { value: { centAmount: 999, currencyCode: 'EUR' } },
        { value: { centAmount: 1099, currencyCode: 'USD' } },
        { value: { centAmount: 1299, currencyCode: 'CHF' } }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('EUR 999;USD 1099;CHF 1299');
    });

    it('should map channel on price', function() {
      this.exportMapping.channelService.id2key['c123'] = 'myKey';
      const prices = [
        { value: { centAmount: 999, currencyCode: 'EUR' }, channel: { id: 'c123' } }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('EUR 999#myKey');
    });

    it('should map customerGroup on price', function() {
      this.exportMapping.customerGroupService.id2name['cg987'] = 'B2B';
      const prices = [
        { value: { centAmount: 9999999, currencyCode: 'USD' }, customerGroup: { id: 'cg987' } }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('USD 9999999 B2B');
    });

    it('should map discounted price', function() {
      const prices = [
        { value: { centAmount: 1999, currencyCode: 'USD' }, discounted: { value: { centAmount: 999, currencyCode: 'USD' } } }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('USD 1999|999');
    });

    it('should map customerGroup and channel on price', function() {
      this.exportMapping.channelService.id2key['channel_123'] = 'WAREHOUSE-1';
      this.exportMapping.customerGroupService.id2name['987-xyz'] = 'sales';
      const prices = [
        { value: { centAmount: -13, currencyCode: 'EUR' }, customerGroup: { id: '987-xyz' }, channel: { id: 'channel_123' } }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('EUR -13 sales#WAREHOUSE-1');
    });

    it('should map price with a validFrom field', function() {
      const prices = [
        { value: { centAmount: -13, currencyCode: 'EUR' }, validFrom: '2001-09-11T14:00:00.000Z' }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('EUR -13$2001-09-11T14:00:00.000Z');
    });

    it('should map price with a validUntil field', function() {
      const prices = [
        { value: { centAmount: -15, currencyCode: 'EUR' }, validUntil: '2015-09-11T14:00:00.000Z' }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('EUR -15~2015-09-11T14:00:00.000Z');
    });

    return it('should map price with validFrom and validUntil fields', function() {
      const prices = [
        { value: { centAmount: -13, currencyCode: 'EUR' }, validFrom: '2001-09-11T14:00:00.000Z', validUntil: '2001-09-12T14:00:00.000Z' }
      ];
      return expect(this.exportMapping._mapPrices(prices)).toBe('EUR -13$2001-09-11T14:00:00.000Z~2001-09-12T14:00:00.000Z');
    });
  });

  describe('#mapImage', function() {
    it('should map single image', function() {
      const images = [
        { url: '//example.com/image.jpg' }
      ];
      return expect(this.exportMapping._mapImages(images)).toBe('//example.com/image.jpg');
    });

    return it('should map multiple images', function() {
      const images = [
        { url: '//example.com/image.jpg' },
        { url: 'https://www.example.com/pic.png' }
      ];
      return expect(this.exportMapping._mapImages(images)).toBe('//example.com/image.jpg;https://www.example.com/pic.png');
    });
  });


  describe('#mapAttribute', function() {
    beforeEach(function() {
      this.exportMapping.typesService = new Types();
      this.productType = {
        id: '123',
        attributes: [
          { name: 'myTextAttrib', type: { name: 'text' } },
          { name: 'myEnumAttrib', type: { name: 'enum' } },
          { name: 'myLenumAttrib', type: { name: 'lenum' } },
          { name: 'myTextSetAttrib', type: { name: 'set', elementType: { name: 'text' } } },
          { name: 'myEnumSetAttrib', type: { name: 'set', elementType: { name: 'enum' } } },
          { name: 'myLenumSetAttrib', type: { name: 'set', elementType: { name: 'lenum' } } }
        ]
      };
      return this.exportMapping.typesService.buildMaps([this.productType]);});

    it('should map simple attribute', function() {
      const attribute = {
        name: 'myTextAttrib',
        value: 'some text'
      };
      return expect(this.exportMapping._mapAttribute(attribute, this.productType.attributes[0].type)).toBe('some text');
    });

    it('should map enum attribute', function() {
      const attribute = {
        name: 'myEnumAttrib',
        value: {
          label: {
            en: 'bla'
          },
          key: 'myEnum'
        }
      };
      return expect(this.exportMapping._mapAttribute(attribute, this.productType.attributes[1].type)).toBe('myEnum');
    });

    it('should map text set attribute', function() {
      const attribute = {
        name: 'myTextSetAttrib',
        value: [ 'x', 'y', 'z' ]
      };
      return expect(this.exportMapping._mapAttribute(attribute, this.productType.attributes[3].type)).toBe('x;y;z');
    });

    return it('should map enum set attribute', function() {
      const attribute = {
        name: 'myEnumSetAttrib',
        value: [
          { label: {
              en: 'bla'
            },
            key: 'myEnum' },
          { label: {
              en: 'foo'
            },
            key: 'myEnum2' }
        ]
      };
      return expect(this.exportMapping._mapAttribute(attribute, this.productType.attributes[4].type)).toBe('myEnum;myEnum2');
    });
  });

  describe('#mapVariant', function() {
    it('should map variant id and sku', function() {
      this.exportMapping.header = new Header([CONS.HEADER_VARIANT_ID, CONS.HEADER_SKU]);
      this.exportMapping.header.toIndex();
      const variant = {
        id: '12',
        sku: 'mySKU',
        attributes: []
      };
      const row = this.exportMapping._mapVariant(variant);
      return expect(row).toEqual([ '12', 'mySKU' ]);
  });

    return it('should map variant attributes', function() {
      this.exportMapping.header = new Header([ 'foo' ]);
      this.exportMapping.header.toIndex();
      this.exportMapping.typesService = new Types();
      const productType = {
        id: '123',
        attributes: [
          { name: 'foo', type: { name: 'text' } }
        ]
      };
      this.exportMapping.typesService.buildMaps([productType]);
      const variant = {
        attributes: [
          { name: 'foo', value: 'bar' }
        ]
      };
      const row = this.exportMapping._mapVariant(variant, productType);
      return expect(row).toEqual([ 'bar' ]);
  });
});

  describe('#mapBaseProduct', function() {
    it('should map productType (name), product id and categories by externalId', function() {
      this.exportMapping.categoryService = new Categories();
      this.exportMapping.categoryService.buildMaps([
        {
          id: '9e6de6ad-cc94-4034-aa9f-276ccb437efd',
          name: {
            en: 'BrilliantCoeur'
          },
          slug: {
            en: 'brilliantcoeur'
          },
          externalId: 'BRI',
        },
        {
          id: '0afacd76-30d8-431e-aff9-376cd1b4c9e6',
          name: {
            en: 'Autumn / Winter 2016'
          },
          slug: {
            en: 'autmn-winter-2016'
          },
          externalId: '9997',
        }
      ]);

      this.exportMapping.categoryBy = 'externalId';
      this.exportMapping.header = new Header(
        [CONS.HEADER_PRODUCT_TYPE,
        CONS.HEADER_ID,
        CONS.HEADER_CATEGORIES]);
      this.exportMapping.header.toIndex();

      const product = {
        id: '123',
        categories: [
          {
            typeId: 'category',
            id: '9e6de6ad-cc94-4034-aa9f-276ccb437efd'
          },
          {
            typeId: 'category',
            id: '0afacd76-30d8-431e-aff9-376cd1b4c9e6'
          }
        ],
        masterVariant: {
          attributes: []
        }
      };

      const type = {
        name: 'myType',
        id: 'typeId123'
      };
      const row = this.exportMapping._mapBaseProduct(product, type);
      return expect(row).toEqual([ 'myType', '123', 'BRI;9997']);
  });

    it('should not map categoryOrderhints when they are not present', function() {
      this.exportMapping.categoryService = new Categories();
      this.exportMapping.categoryService.buildMaps([
        {
          id: '9e6de6ad-cc94-4034-aa9f-276ccb437efd',
          name: {
            en: 'BrilliantCoeur'
          },
          slug: {
            en: 'brilliantcoeur'
          },
          externalId: 'BRI',
        },
        {
          id: '0afacd76-30d8-431e-aff9-376cd1b4c9e6',
          name: {
            en: 'Autumn / Winter 2016'
          },
          slug: {
            en: 'autmn-winter-2016'
          },
          externalId: '9997',
        }
      ]);

      this.exportMapping.categoryBy = 'externalId';
      this.exportMapping.header = new Header(
        [CONS.HEADER_PRODUCT_TYPE,
          CONS.HEADER_ID,
          CONS.HEADER_CATEGORY_ORDER_HINTS]);
      this.exportMapping.header.toIndex();

      const product = {
        id: '123',
        categories: [
          {
            typeId: 'category',
            id: '9e6de6ad-cc94-4034-aa9f-276ccb437efd'
          },
          {
            typeId: 'category',
            id: '0afacd76-30d8-431e-aff9-376cd1b4c9e6'
          }
        ],
        masterVariant: {
          attributes: []
        }
      };

      const type = {
        name: 'myType',
        id: 'typeId123'
      };
      const row = this.exportMapping._mapBaseProduct(product, type);

      return expect(row).toEqual([ 'myType', '123', '']);
  });

    it('should map productType (name), product id and categoryOrderhints by externalId', function() {
      this.exportMapping.categoryService = new Categories();
      this.exportMapping.categoryService.buildMaps([
        {
          id: '9e6de6ad-cc94-4034-aa9f-276ccb437efd',
          name: {
            en: 'BrilliantCoeur'
          },
          slug: {
            en: 'brilliantcoeur'
          },
          externalId: 'BRI',
        },
        {
          id: '0afacd76-30d8-431e-aff9-376cd1b4c9e6',
          name: {
            en: 'Autumn / Winter 2016'
          },
          slug: {
            en: 'autmn-winter-2016'
          },
          externalId: '9997',
        }
      ]);

      this.exportMapping.categoryBy = 'externalId';
      this.exportMapping.header = new Header(
        [CONS.HEADER_PRODUCT_TYPE,
          CONS.HEADER_ID,
          CONS.HEADER_CATEGORY_ORDER_HINTS]);
      this.exportMapping.header.toIndex();

      const product = {
        id: '123',
        categoryOrderHints: {
          '9e6de6ad-cc94-4034-aa9f-276ccb437efd': '0.9283',
          '0afacd76-30d8-431e-aff9-376cd1b4c9e6': '0.3223'
        },
        categories: [],
        masterVariant: {
          attributes: []
        }
      };

      const type = {
        name: 'myType',
        id: 'typeId123'
      };
      const row = this.exportMapping._mapBaseProduct(product, type);

      return expect(row).toEqual([ 'myType', '123', '9e6de6ad-cc94-4034-aa9f-276ccb437efd:0.9283;0afacd76-30d8-431e-aff9-376cd1b4c9e6:0.3223']);
  });

    it('should map createdAt and lastModifiedAt', function() {
      this.exportMapping.header = new Header(
        [CONS.HEADER_CREATED_AT,
        CONS.HEADER_LAST_MODIFIED_AT]);
      this.exportMapping.header.toIndex();

      const createdAt = new Date();
      const lastModifiedAt = new Date();

      const product = {
        createdAt,
        lastModifiedAt,
        masterVariant: {
          attributes: []
        }
      };

      const type = {
        name: 'myType',
        id: 'typeId123'
      };
      const row = this.exportMapping._mapBaseProduct(product, type);
      return expect(row).toEqual([ createdAt, lastModifiedAt ]);
  });


    it('should map tax category name', function() {
      this.exportMapping.header = new Header([CONS.HEADER_TAX]);
      this.exportMapping.header.toIndex();
      this.exportMapping.taxService = {
        id2name: {
          tax123: 'myTax'
        }
      };

      const product = {
        id: '123',
        masterVariant: {
          attributes: []
        },
        taxCategory: {
          id: 'tax123'
        }
      };
      const type = {
        name: 'myType',
        id: 'typeId123'
      };
      const row = this.exportMapping._mapBaseProduct(product, type);
      return expect(row).toEqual([ 'myTax' ]);
  });


    return it('should map localized base attributes', function() {
      this.exportMapping.header = new Header(['name.de','slug.it','description.en','searchKeywords.de']);
      this.exportMapping.header.toIndex();
      const product = {
        id: '123',
        masterVariant: {
          attributes: []
        },
        name: {
          de: 'Hallo',
          en: 'Hello',
          it: 'Ciao'
        },
        slug: {
          de: 'hallo',
          en: 'hello',
          it: 'ciao'
        },
        description: {
          de: 'Bla bla',
          en: 'Foo bar',
          it: 'Ciao Bella'
        },
        searchKeywords: {
          de:
            [
              ({text: "test"}),
              ({text: "sample"})
            ],
          en:
            [
              ({text: "drops"}),
              ({text: "kocher"})
            ],
          it:
            [
              ({text: "bla"}),
              ({text: "foo"}),
              ({text: "bar"})
            ]
        }
      };
      const row = this.exportMapping._mapBaseProduct(product, {});
      return expect(row).toEqual([ 'Hallo', 'ciao', 'Foo bar','test;sample']);
  });
});

  describe('#mapLenumAndSetOfLenum', function() {
    beforeEach(function() {
      this.exportMapping.typesService = new Types();
      this.productType = {
        id: '123',
        attributes: [
          { name: 'myLenumAttrib', type: { name: 'lenum' } },
          { name: 'myLenumSetAttrib', type: { name: 'set', elementType: { name: 'lenum' } } }
        ]
      };
      return this.exportMapping.typesService.buildMaps([this.productType]);});

    it('should map key of lenum and set of lenum if no language is given', function() {
      this.exportMapping.header = new Header(['myLenumAttrib.en','myLenumAttrib','myLenumSetAttrib.fr-BE','myLenumSetAttrib']);
      this.exportMapping.header.toIndex();
      const variant = {
        attributes: [
          {
            name: 'myLenumAttrib',
            value: {
              key: 'myEnum',
              label: {
                en: 'bla',
                de: 'blub'
              }
            }
          },
          {
            name: 'myLenumSetAttrib',
            value: [
              {
                key: 'drops',
                label: {
                  "fr-BE": 'le drops',
                  de: 'der drops',
                  en: 'the drops'
                }
              },
              {
                "key": "honk",
                "label": {
                  "en": "the honk",
                  "fr-BE": "le honk",
                  "de-DE": "der honk"
                }
              }
            ]
          }
        ]
      };
      const row = this.exportMapping._mapVariant(variant, this.productType);
      return expect(row).toEqual([ 'bla','myEnum','le drops;le honk','drops;honk']);
  });

    return it('should map the labels of lenum and set of lenum if language is given', function() {
      this.exportMapping.header = new Header(['myLenumAttrib.en','myLenumSetAttrib.fr-BE']);
      this.exportMapping.header.toIndex();
      const variant = {
        attributes: [
          {
            name: 'myLenumAttrib',
            value: {
              key: 'myEnum',
              label: {
                en: 'bla',
                de: 'blub'
              }
            }
          },
          {
            name: 'myLenumSetAttrib',
            value: [
              {
                key: 'drops',
                label: {
                  "fr-BE": 'le drops',
                  de: 'der drops',
                  en: 'the drops'
                }
              },
              {
                "key": "honk",
                "label": {
                  "en": "the honk",
                  "fr-BE": "le honk",
                  "de-DE": "der honk"
                }
              }
            ]
          }
        ]
      };
      const row = this.exportMapping._mapVariant(variant, this.productType);
      return expect(row).toEqual([ 'bla','le drops;le honk' ]);
  });
});

  describe('#mapLtextSet', function() {
    beforeEach(function() {
      this.exportMapping.typesService = new Types();
      this.productType = {
        id: '123',
        attributes: [
          { name: 'myLtextSetAttrib', type: { name: 'set', elementType: { name: 'ltext' } } }
        ]
      };
      return this.exportMapping.typesService.buildMaps([this.productType]);});
    it('should map set of ltext', function() {
      this.exportMapping.header = new Header(['myLtextSetAttrib.de','myLtextSetAttrib.en']);
      this.exportMapping.header.toIndex();
      const variant = {
        attributes: [
          {
            name: 'myLtextSetAttrib',
            value: [
              {"en": "foo1", "de": "barA"},
              {"en": "foo2", "de": "barB"},
              {"de": "barC", "nl": "invisible"}
            ]
          }
        ]
      };
      const row = this.exportMapping._mapVariant(variant, this.productType);
      const expected = [ 'barA;barB;barC','foo1;foo2' ];
      return expect(row).toEqual(expected);
    });

    it('should return undefined for invalid set of attributes', function() {
      this.exportMapping.header = new Header(['myLtextSetAttrib','myLtextSetAttrib.en', 'myLtextSetAttrib.de']);
      this.exportMapping.header.toIndex();
      const variant = {
        attributes: [
          {
            name: 'myLtextSetAttrib',
            value: [
              {"en": "foo1", "de": "barA"},
              {"en": "foo2", "de": "barB"},
              {"de": "barC", "nl": "invisible"}
            ]
          }
        ]
      };
      const row = this.exportMapping._mapVariant(variant, this.productType);
      const expected = [ undefined,'foo1;foo2', 'barA;barB;barC' ];
      return expect(row).toEqual(expected);
    });

    it('should ignore trailing invalid set of attributes', function() {
      this.exportMapping.header = new Header(['myLtextSetAttrib.en', 'myLtextSetAttrib.de', 'foo', 'bar']);
      this.exportMapping.header.toIndex();
      const variant = {
        attributes: [
          {
            name: 'myLtextSetAttrib',
            value: [
              {"en": "foo1", "de": "barA"},
              {"en": "foo2", "de": "barB"},
              {"de": "barC", "nl": "invisible"}
            ]
          }
        ]
      };
      const row = this.exportMapping._mapVariant(variant, this.productType);
      const expected = [ 'foo1;foo2', 'barA;barB;barC' ];
      return expect(row).toEqual(expected);
    });

    return it('should return undefined for invalid set of attributes that is not trailing', function() {
      this.exportMapping.header = new Header(['myLtextSetAttrib.en', 'foo', 'bar', 'myLtextSetAttrib.de']);
      this.exportMapping.header.toIndex();
      const variant = {
        attributes: [
          {
            name: 'myLtextSetAttrib',
            value: [
              {"en": "foo1", "de": "barA"},
              {"en": "foo2", "de": "barB"},
              {"de": "barC", "nl": "invisible"}
            ]
          }
        ]
      };
      const row = this.exportMapping._mapVariant(variant, this.productType);
      const expected = [ 'foo1;foo2', undefined, undefined, 'barA;barB;barC' ];
      return expect(row).toEqual(expected);
    });
  });

  return describe('#createTemplate', function() {
    beforeEach(function() {
      return this.productType =
        {attributes: []};});

    it('should do nothing if there are no attributes', function() {
      const template = this.exportMapping.createTemplate(this.productType);
      expect(_.intersection(template, [ CONS.HEADER_PUBLISHED, CONS.HEADER_HAS_STAGED_CHANGES ])).toEqual([ CONS.HEADER_PUBLISHED, CONS.HEADER_HAS_STAGED_CHANGES ]);
      expect(_.intersection(template, CONS.BASE_HEADERS)).toEqual(CONS.BASE_HEADERS);
      expect(_.intersection(template, CONS.SPECIAL_HEADERS)).toEqual(CONS.SPECIAL_HEADERS);
      return _.each(CONS.BASE_LOCALIZED_HEADERS, h => expect(_.contains(template, `${h}.en`)).toBe(true));
    });

    it('should get attribute name for all kind of types', function() {
      this.productType.attributes.push({ name: 'a-enum', type: { name: 'enum' } });
      this.productType.attributes.push({ name: 'a-lenum', type: { name: 'lenum' } });
      this.productType.attributes.push({ name: 'a-text', type: { name: 'text' } });
      this.productType.attributes.push({ name: 'a-number', type: { name: 'number' } });
      this.productType.attributes.push({ name: 'a-money', type: { name: 'money' } });
      this.productType.attributes.push({ name: 'a-date', type: { name: 'date' } });
      this.productType.attributes.push({ name: 'a-time', type: { name: 'time' } });
      this.productType.attributes.push({ name: 'a-datetime', type: { name: 'datetime' } });
      const template = this.exportMapping.createTemplate(this.productType);

      const expectedHeaders = [ 'a-enum', 'a-lenum', 'a-text', 'a-number', 'a-money', 'a-date', 'a-time', 'a-datetime' ];
      return _.map(expectedHeaders, h => expect(_.contains(template, h)).toBe(true));
    });

    return it('should add headers for all languages', function() {
      this.productType.attributes.push({ name: 'multilang', type: { name: 'ltext' } });
      const template = this.exportMapping.createTemplate(this.productType, [ 'de', 'en', 'it' ]);
      _.each(CONS.BASE_LOCALIZED_HEADERS, function(h) {
        expect(_.contains(template, `${h}.de`)).toBe(true);
        expect(_.contains(template, `${h}.en`)).toBe(true);
        return expect(_.contains(template, `${h}.it`)).toBe(true);
      });
      expect(_.contains(template, "multilang.de")).toBe(true);
      expect(_.contains(template, "multilang.en")).toBe(true);
      return expect(_.contains(template, "multilang.it")).toBe(true);
    });
  });
});
