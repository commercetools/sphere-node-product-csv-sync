_ = require 'underscore'
Types = require '../lib/types'
CONS = require '../lib/constants'
{ExportMapping, Header, Categories} = require '../lib/main'

describe 'ExportMapping', ->

  beforeEach ->
    @exportMapping = new ExportMapping()

  describe '#constructor', ->
    it 'should initialize', ->
      expect(@exportMapping).toBeDefined()

  describe '#mapPrices', ->
    beforeEach ->
      @exportMapping.channelService =
        id2key: {}
      @exportMapping.customerGroupService =
        id2name: {}
    it 'should map simple price', ->
      prices = [
        { value: { centAmount: 999, currencyCode: 'EUR' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR 999'

    it 'should map price with country', ->
      prices = [
        { value: { centAmount: 77, currencyCode: 'EUR' }, country: 'DE' }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'DE-EUR 77'

    it 'should map multiple prices', ->
      prices = [
        { value: { centAmount: 999, currencyCode: 'EUR' } }
        { value: { centAmount: 1099, currencyCode: 'USD' } }
        { value: { centAmount: 1299, currencyCode: 'CHF' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR 999;USD 1099;CHF 1299'

    it 'should map channel on price', ->
      @exportMapping.channelService.id2key['c123'] = 'myKey'
      prices = [
        { value: { centAmount: 999, currencyCode: 'EUR' }, channel: { id: 'c123' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR 999#myKey'

    it 'should map customerGroup on price', ->
      @exportMapping.customerGroupService.id2name['cg987'] = 'B2B'
      prices = [
        { value: { centAmount: 9999999, currencyCode: 'USD' }, customerGroup: { id: 'cg987' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'USD 9999999 B2B'

    it 'should map discounted price', ->
      prices = [
        { value: { centAmount: 1999, currencyCode: 'USD' }, discounted: { value: { centAmount: 999, currencyCode: 'USD' } } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'USD 1999|999'

    it 'should map customerGroup and channel on price', ->
      @exportMapping.channelService.id2key['channel_123'] = 'WAREHOUSE-1'
      @exportMapping.customerGroupService.id2name['987-xyz'] = 'sales'
      prices = [
        { value: { centAmount: -13, currencyCode: 'EUR' }, customerGroup: { id: '987-xyz' }, channel: { id: 'channel_123' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR -13 sales#WAREHOUSE-1'

    it 'should map price with a validFrom field', ->
      prices = [
        { value: { centAmount: -13, currencyCode: 'EUR' }, validFrom: '2001-09-11T14:00:00.000Z' }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR -13$2001-09-11T14:00:00.000Z'

    it 'should map price with a validUntil field', ->
      prices = [
        { value: { centAmount: -15, currencyCode: 'EUR' }, validUntil: '2015-09-11T14:00:00.000Z' }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR -15~2015-09-11T14:00:00.000Z'

    it 'should map price with validFrom and validUntil fields', ->
      prices = [
        { value: { centAmount: -13, currencyCode: 'EUR' }, validFrom: '2001-09-11T14:00:00.000Z', validUntil: '2001-09-12T14:00:00.000Z' }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR -13$2001-09-11T14:00:00.000Z~2001-09-12T14:00:00.000Z'

    it 'should map tiers with single priceTier on prices', ->
      prices = [
        { value: { centAmount: 500, currencyCode: 'EUR' }, tiers: [{ value: { centAmount: 450, currencyCode: 'EUR' }, minimumQuantity: 1000 }] }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR 500%EUR 450 @1000'

    it 'should map tiers with multiple priceTiers on prices', ->
      prices = [
        { value: { centAmount: 500, currencyCode: 'EUR' }, tiers: [{ value: { centAmount: 450, currencyCode: 'EUR' }, minimumQuantity: 1000 },{ value: { centAmount: 400, currencyCode: 'EUR' }, minimumQuantity: 3000 },{ value: { centAmount: 350, currencyCode: 'EUR' }, minimumQuantity: 5000 }] }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR 500%EUR 450 @1000%EUR 400 @3000%EUR 350 @5000'

  describe '#mapTiers', ->
    it 'should map tiers with single priceTier ', ->
      tiers = [
        {value: { centAmount: 900, currencyCode: 'EUR' }, minimumQuantity: 1000}
      ]
      expect(@exportMapping._mapTiers tiers).toBe 'EUR 900 @1000'

    it 'should map tiers with multiple priceTiers ', ->
      tiers = [
        { value: { centAmount: 100, currencyCode: 'EUR' }, minimumQuantity: 1000 }
        { value: { centAmount: 90, currencyCode: 'EUR' }, minimumQuantity: 2000 }
        { value: { centAmount: 80, currencyCode: 'EUR' }, minimumQuantity: 3000 }
      ]
      expect(@exportMapping._mapTiers tiers).toBe 'EUR 100 @1000%EUR 90 @2000%EUR 80 @3000'

  describe '#mapImage', ->
    it 'should map single image', ->
      images = [
        { url: '//example.com/image.jpg', label: 'custom' }
      ]
      expect(@exportMapping._mapImages images).toBe '//example.com/image.jpg|custom|0x0'

    it 'should map multiple images', ->
      images = [
        { url: '//example.com/image.jpg' }
        { url: 'https://www.example.com/pic.png', label: "custom", dimensions: { w: 100, h: 100 }}
      ]
      expect(@exportMapping._mapImages images).toBe '//example.com/image.jpg||0x0;https://www.example.com/pic.png|custom|100x100'


  describe '#mapAttribute', ->
    beforeEach ->
      @exportMapping.typesService = new Types()
      @productType =
        id: '123'
        attributes: [
          { name: 'myTextAttrib', type: { name: 'text' } }
          { name: 'myEnumAttrib', type: { name: 'enum' } }
          { name: 'myLenumAttrib', type: { name: 'lenum' } }
          { name: 'myTextSetAttrib', type: { name: 'set', elementType: { name: 'text' } } }
          { name: 'myEnumSetAttrib', type: { name: 'set', elementType: { name: 'enum' } } }
          { name: 'myLenumSetAttrib', type: { name: 'set', elementType: { name: 'lenum' } } }
        ]
      @exportMapping.typesService.buildMaps [@productType]

    it 'should map simple attribute', ->
      attribute =
        name: 'myTextAttrib'
        value: 'some text'
      expect(@exportMapping._mapAttribute attribute, @productType.attributes[0].type).toBe 'some text'

    it 'should map enum attribute', ->
      attribute =
        name: 'myEnumAttrib'
        value:
          label:
            en: 'bla'
          key: 'myEnum'
      expect(@exportMapping._mapAttribute attribute, @productType.attributes[1].type).toBe 'myEnum'

    it 'should map text set attribute', ->
      attribute =
        name: 'myTextSetAttrib'
        value: [ 'x', 'y', 'z' ]
      expect(@exportMapping._mapAttribute attribute, @productType.attributes[3].type).toBe 'x;y;z'

    it 'should map enum set attribute', ->
      attribute =
        name: 'myEnumSetAttrib'
        value: [
          { label:
              en: 'bla'
            key: 'myEnum' }
          { label:
              en: 'foo'
            key: 'myEnum2' }
        ]
      expect(@exportMapping._mapAttribute attribute, @productType.attributes[4].type).toBe 'myEnum;myEnum2'

  describe '#mapVariant', ->
    it 'should map variant id and sku', ->
      @exportMapping.header = new Header([CONS.HEADER_VARIANT_ID, CONS.HEADER_SKU])
      @exportMapping.header.toIndex()
      variant =
        id: '12'
        sku: 'mySKU'
        attributes: []
      row = @exportMapping._mapVariant(variant)
      expect(row).toEqual [ '12', 'mySKU' ]

    it 'should map variant attributes', ->
      @exportMapping.header = new Header([ 'foo' ])
      @exportMapping.header.toIndex()
      @exportMapping.typesService = new Types()
      productType =
        id: '123'
        attributes: [
          { name: 'foo', type: { name: 'text' } }
        ]
      @exportMapping.typesService.buildMaps [productType]
      variant =
        attributes: [
          { name: 'foo', value: 'bar' }
        ]
      row = @exportMapping._mapVariant(variant, productType)
      expect(row).toEqual [ 'bar' ]

  describe '#mapBaseProduct', ->
    it 'should map productType (name), product id and categories by externalId', ->
      @exportMapping.categoryService = new Categories()
      @exportMapping.categoryService.buildMaps [
        {
          id: '9e6de6ad-cc94-4034-aa9f-276ccb437efd',
          name:
            en: 'BrilliantCoeur',
          slug:
            en: 'brilliantcoeur',
          externalId: 'BRI',
        },
        {
          id: '0afacd76-30d8-431e-aff9-376cd1b4c9e6',
          name:
            en: 'Autumn / Winter 2016',
          slug:
            en: 'autmn-winter-2016',
          externalId: '9997',
        }
      ]

      @exportMapping.categoryBy = 'externalId'
      @exportMapping.header = new Header(
        [CONS.HEADER_PRODUCT_TYPE,
        CONS.HEADER_ID,
        CONS.HEADER_CATEGORIES])
      @exportMapping.header.toIndex()

      product =
        id: '123'
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
        masterVariant:
          attributes: []

      type =
        name: 'myType'
        id: 'typeId123'
      row = @exportMapping._mapBaseProduct(product, type)
      expect(row).toEqual [ 'myType', '123', 'BRI;9997']

    it 'should not map categoryOrderhints when they are not present', ->
      @exportMapping.categoryService = new Categories()
      @exportMapping.categoryService.buildMaps [
        {
          id: '9e6de6ad-cc94-4034-aa9f-276ccb437efd',
          name:
            en: 'BrilliantCoeur',
          slug:
            en: 'brilliantcoeur',
          externalId: 'BRI',
        },
        {
          id: '0afacd76-30d8-431e-aff9-376cd1b4c9e6',
          name:
            en: 'Autumn / Winter 2016',
          slug:
            en: 'autmn-winter-2016',
          externalId: '9997',
        }
      ]

      @exportMapping.categoryBy = 'externalId'
      @exportMapping.header = new Header(
        [CONS.HEADER_PRODUCT_TYPE,
          CONS.HEADER_ID,
          CONS.HEADER_CATEGORY_ORDER_HINTS])
      @exportMapping.header.toIndex()

      product =
        id: '123'
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
        masterVariant:
          attributes: []

      type =
        name: 'myType'
        id: 'typeId123'
      row = @exportMapping._mapBaseProduct(product, type)

      expect(row).toEqual [ 'myType', '123', '']

    it 'should map productType (name), product id and categoryOrderhints by externalId', ->
      @exportMapping.categoryService = new Categories()
      @exportMapping.categoryService.buildMaps [
        {
          id: '9e6de6ad-cc94-4034-aa9f-276ccb437efd',
          name:
            en: 'BrilliantCoeur',
          slug:
            en: 'brilliantcoeur',
          externalId: 'BRI',
        },
        {
          id: '0afacd76-30d8-431e-aff9-376cd1b4c9e6',
          name:
            en: 'Autumn / Winter 2016',
          slug:
            en: 'autmn-winter-2016',
          externalId: '9997',
        }
      ]

      @exportMapping.categoryBy = 'externalId'
      @exportMapping.header = new Header(
        [CONS.HEADER_PRODUCT_TYPE,
          CONS.HEADER_ID,
          CONS.HEADER_CATEGORY_ORDER_HINTS])
      @exportMapping.header.toIndex()

      product =
        id: '123'
        categoryOrderHints: {
          '9e6de6ad-cc94-4034-aa9f-276ccb437efd': '0.9283'
          '0afacd76-30d8-431e-aff9-376cd1b4c9e6': '0.3223'
        },
        categories: [],
        masterVariant:
          attributes: []

      type =
        name: 'myType'
        id: 'typeId123'
      row = @exportMapping._mapBaseProduct(product, type)

      expect(row).toEqual [ 'myType', '123', '9e6de6ad-cc94-4034-aa9f-276ccb437efd:0.9283;0afacd76-30d8-431e-aff9-376cd1b4c9e6:0.3223']

    it 'should map createdAt and lastModifiedAt', ->
      @exportMapping.header = new Header(
        [CONS.HEADER_CREATED_AT,
        CONS.HEADER_LAST_MODIFIED_AT])
      @exportMapping.header.toIndex()

      createdAt = new Date()
      lastModifiedAt = new Date()

      product =
        createdAt: createdAt
        lastModifiedAt: lastModifiedAt
        masterVariant:
          attributes: []

      type =
        name: 'myType'
        id: 'typeId123'
      row = @exportMapping._mapBaseProduct(product, type)
      expect(row).toEqual [ createdAt, lastModifiedAt ]


    it 'should map tax category name', ->
      @exportMapping.header = new Header([CONS.HEADER_TAX])
      @exportMapping.header.toIndex()
      @exportMapping.taxService =
        id2name:
          tax123: 'myTax'

      product =
        id: '123'
        masterVariant:
          attributes: []
        taxCategory:
          id: 'tax123'
      type =
        name: 'myType'
        id: 'typeId123'
      row = @exportMapping._mapBaseProduct(product, type)
      expect(row).toEqual [ 'myTax' ]

    it 'should map state key', ->
      @exportMapping.header = new Header([CONS.HEADER_STATE])
      @exportMapping.header.toIndex()
      @exportMapping.stateService =
        id2key:
          state123: 'myState'

      product =
        id: '123'
        masterVariant:
          attributes: []
        state:
          id: 'state123'
      type =
        name: 'myType'
        id: 'typeId123'
      row = @exportMapping._mapBaseProduct(product, type)
      expect(row).toEqual [ 'myState' ]


    it 'should map localized base attributes', ->
      @exportMapping.header = new Header(['name.de','slug.it','description.en','searchKeywords.de'])
      @exportMapping.header.toIndex()
      product =
        id: '123'
        masterVariant:
          attributes: []
        name:
          de: 'Hallo'
          en: 'Hello'
          it: 'Ciao'
        slug:
          de: 'hallo'
          en: 'hello'
          it: 'ciao'
        description:
          de: 'Bla bla'
          en: 'Foo bar'
          it: 'Ciao Bella'
        searchKeywords:
          de:
            [
              (text: "test")
              (text: "sample")
            ]
          en:
            [
              (text: "drops")
              (text: "kocher")
            ]
          it:
            [
              (text: "bla")
              (text: "foo")
              (text: "bar")
            ]
      row = @exportMapping._mapBaseProduct(product, {})
      expect(row).toEqual [ 'Hallo', 'ciao', 'Foo bar','test;sample']

  describe '#mapLenumAndSetOfLenum', ->
    beforeEach ->
      @exportMapping.typesService = new Types()
      @productType =
        id: '123'
        attributes: [
          { name: 'myLenumAttrib', type: { name: 'lenum' } }
          { name: 'myLenumSetAttrib', type: { name: 'set', elementType: { name: 'lenum' } } }
        ]
      @exportMapping.typesService.buildMaps [@productType]

    it 'should map key of lenum and set of lenum if no language is given', ->
      @exportMapping.header = new Header(['myLenumAttrib.en','myLenumAttrib','myLenumSetAttrib.fr-BE','myLenumSetAttrib'])
      @exportMapping.header.toIndex()
      variant =
        attributes: [
          {
            name: 'myLenumAttrib'
            value:
              key: 'myEnum'
              label:
                en: 'bla'
                de: 'blub'
          },
          {
            name: 'myLenumSetAttrib'
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
      row = @exportMapping._mapVariant(variant, @productType)
      expect(row).toEqual [ 'bla','myEnum','le drops;le honk','drops;honk']

    it 'should map the labels of lenum and set of lenum if language is given', ->
      @exportMapping.header = new Header(['myLenumAttrib.en','myLenumSetAttrib.fr-BE'])
      @exportMapping.header.toIndex()
      variant =
        attributes: [
          {
            name: 'myLenumAttrib'
            value:
              key: 'myEnum'
              label:
                en: 'bla'
                de: 'blub'
          },
          {
            name: 'myLenumSetAttrib'
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
      row = @exportMapping._mapVariant(variant, @productType)
      expect(row).toEqual [ 'bla','le drops;le honk' ]

  describe '#mapLtextSet', ->
    beforeEach ->
      @exportMapping.typesService = new Types()
      @productType =
        id: '123'
        attributes: [
          { name: 'myLtextSetAttrib', type: { name: 'set', elementType: { name: 'ltext' } } }
        ]
      @exportMapping.typesService.buildMaps [@productType]
    it 'should map set of ltext', ->
      @exportMapping.header = new Header(['myLtextSetAttrib.de','myLtextSetAttrib.en'])
      @exportMapping.header.toIndex()
      variant =
        attributes: [
          {
            name: 'myLtextSetAttrib'
            value: [
              {"en": "foo1", "de": "barA"},
              {"en": "foo2", "de": "barB"},
              {"de": "barC", "nl": "invisible"}
            ]
          }
        ]
      row = @exportMapping._mapVariant(variant, @productType)
      expected = [ 'barA;barB;barC','foo1;foo2' ]
      expect(row).toEqual expected

    it 'should return undefined for invalid set of attributes', ->
      @exportMapping.header = new Header(['myLtextSetAttrib','myLtextSetAttrib.en', 'myLtextSetAttrib.de'])
      @exportMapping.header.toIndex()
      variant =
        attributes: [
          {
            name: 'myLtextSetAttrib'
            value: [
              {"en": "foo1", "de": "barA"},
              {"en": "foo2", "de": "barB"},
              {"de": "barC", "nl": "invisible"}
            ]
          }
        ]
      row = @exportMapping._mapVariant(variant, @productType)
      expected = [ undefined,'foo1;foo2', 'barA;barB;barC' ]
      expect(row).toEqual expected

    it 'should ignore trailing invalid set of attributes', ->
      @exportMapping.header = new Header(['myLtextSetAttrib.en', 'myLtextSetAttrib.de', 'foo', 'bar'])
      @exportMapping.header.toIndex()
      variant =
        attributes: [
          {
            name: 'myLtextSetAttrib'
            value: [
              {"en": "foo1", "de": "barA"},
              {"en": "foo2", "de": "barB"},
              {"de": "barC", "nl": "invisible"}
            ]
          }
        ]
      row = @exportMapping._mapVariant(variant, @productType)
      expected = [ 'foo1;foo2', 'barA;barB;barC' ]
      expect(row).toEqual expected

    it 'should return undefined for invalid set of attributes that is not trailing', ->
      @exportMapping.header = new Header(['myLtextSetAttrib.en', 'foo', 'bar', 'myLtextSetAttrib.de'])
      @exportMapping.header.toIndex()
      variant =
        attributes: [
          {
            name: 'myLtextSetAttrib'
            value: [
              {"en": "foo1", "de": "barA"},
              {"en": "foo2", "de": "barB"},
              {"de": "barC", "nl": "invisible"}
            ]
          }
        ]
      row = @exportMapping._mapVariant(variant, @productType)
      expected = [ 'foo1;foo2', undefined, undefined, 'barA;barB;barC' ]
      expect(row).toEqual expected

  describe '#createTemplate', ->
    beforeEach ->
      @productType =
        attributes: []

    it 'should do nothing if there are no attributes', ->
      template = @exportMapping.createTemplate @productType
      expect(_.intersection template, [ CONS.HEADER_PUBLISHED, CONS.HEADER_HAS_STAGED_CHANGES ]).toEqual [ CONS.HEADER_PUBLISHED, CONS.HEADER_HAS_STAGED_CHANGES ]
      expect(_.intersection template, CONS.BASE_HEADERS).toEqual CONS.BASE_HEADERS
      expect(_.intersection template, CONS.SPECIAL_HEADERS).toEqual CONS.SPECIAL_HEADERS
      _.each CONS.BASE_LOCALIZED_HEADERS, (h) ->
        expect(_.contains template, "#{h}.en").toBe true

    it 'should get attribute name for all kind of types', ->
      @productType.attributes.push { name: 'a-enum', type: { name: 'enum' } }
      @productType.attributes.push { name: 'a-lenum', type: { name: 'lenum' } }
      @productType.attributes.push { name: 'a-text', type: { name: 'text' } }
      @productType.attributes.push { name: 'a-number', type: { name: 'number' } }
      @productType.attributes.push { name: 'a-money', type: { name: 'money' } }
      @productType.attributes.push { name: 'a-date', type: { name: 'date' } }
      @productType.attributes.push { name: 'a-time', type: { name: 'time' } }
      @productType.attributes.push { name: 'a-datetime', type: { name: 'datetime' } }
      template = @exportMapping.createTemplate @productType

      expectedHeaders = [ 'a-enum', 'a-lenum', 'a-text', 'a-number', 'a-money', 'a-date', 'a-time', 'a-datetime' ]
      _.map expectedHeaders, (h) ->
        expect(_.contains template, h).toBe true

    it 'should add headers for all languages', ->
      @productType.attributes.push { name: 'multilang', type: { name: 'ltext' } }
      template = @exportMapping.createTemplate @productType, [ 'de', 'en', 'it' ]
      _.each CONS.BASE_LOCALIZED_HEADERS, (h) ->
        expect(_.contains template, "#{h}.de").toBe true
        expect(_.contains template, "#{h}.en").toBe true
        expect(_.contains template, "#{h}.it").toBe true
      expect(_.contains template, "multilang.de").toBe true
      expect(_.contains template, "multilang.en").toBe true
      expect(_.contains template, "multilang.it").toBe true

  describe '#mapOnlyMasterVariants', ->
    beforeEach ->
      @sampleProduct =
        id: '123'
        productType:
          id: 'myType'
        name:
          de: 'Hallo'
        slug:
          de: 'hallo'
        description:
          de: 'Bla bla'
        masterVariant:
          id: 1
          sku: 'var1'
          key: 'var1Key'
        variants: [
          {
            id: 2
            sku: 'var2'
            key: 'var2Key'
          }
        ]

    it 'should map all variants', ->
      _exportMapping = new ExportMapping(
        typesService:
          id2index:
            myType: 0
      )
      _exportMapping.header = new Header([CONS.HEADER_VARIANT_ID, CONS.HEADER_SKU])
      _exportMapping.header.toIndex()

      type =
        name: 'myType'
        id: 'typeId123'
      mappedProduct = _exportMapping.mapProduct @sampleProduct, [type]
      # both variants should be mapped
      expect(mappedProduct).toEqual [ [ 1, 'var1' ], [ 2, 'var2' ] ]

    it 'should map only masterVariant', ->
      _exportMapping = new ExportMapping(
        onlyMasterVariants: true
        typesService:
          id2index:
            myType: 0
      )
      _exportMapping.header = new Header([CONS.HEADER_VARIANT_ID, CONS.HEADER_SKU])
      _exportMapping.header.toIndex()

      type =
        name: 'myType'
        id: 'typeId123'
      mappedProduct = _exportMapping.mapProduct @sampleProduct, [type]
      # only masterVariant should be mapped
      expect(mappedProduct).toEqual [ [ 1, 'var1' ] ]
