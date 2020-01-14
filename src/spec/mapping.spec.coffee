_ = require 'underscore'
CONS = require '../lib/constants'
{Header, Mapping, Validator} = require '../lib/main'
Categories = require '../lib/categories'

# API Types
Types = require '../lib/types'
Categories = require '../lib/categories'
CustomerGroups = require '../lib/customergroups'
Taxes = require '../lib/taxes'
Channels = require '../lib/channels'

describe 'Mapping', ->
  beforeEach ->
    options = {
      types : new Types(),
      customerGroups : new CustomerGroups(),
      categories : new Categories(),
      taxes : new Taxes(),
      channels : new Channels(),
    }
    @validator = new Validator(options)
    @map = new Mapping(options)

  describe '#constructor', ->
    it 'should initialize', ->
      expect(-> new Mapping()).toBeDefined()
      expect(@map).toBeDefined()

  describe '#isValidValue', ->
    it 'should return false for undefined and null', ->
      expect(@map.isValidValue(undefined)).toBe false
      expect(@map.isValidValue(null)).toBe false
    it 'should return false for empty string', ->
      expect(@map.isValidValue('')).toBe false
      expect(@map.isValidValue("")).toBe false
    it 'should return true for strings with length > 0', ->
      expect(@map.isValidValue("foo")).toBe true

  describe '#ensureValidSlug', ->
    it 'should accept unique slug', ->
      expect(@map.ensureValidSlug 'foo').toBe 'foo'

    it 'should enhance duplicate slug', ->
      expect(@map.ensureValidSlug 'foo').toBe 'foo'
      expect(@map.ensureValidSlug 'foo').toMatch /foo\d{5}/

    it 'should fail for undefined or null', ->
      expect(@map.ensureValidSlug undefined, 99).toBeUndefined()
      expect(@map.errors[0]).toBe "[row 99:slug] Can't generate valid slug out of 'undefined'!"

      expect(@map.ensureValidSlug null, 3).toBeUndefined()
      expect(@map.errors[1]).toBe "[row 3:slug] Can't generate valid slug out of 'null'!"

    it 'should fail for too short slug', ->
      expect(@map.ensureValidSlug '1', 7).toBeUndefined()
      expect(_.size @map.errors).toBe 1
      expect(@map.errors[0]).toBe "[row 7:slug] Can't generate valid slug out of '1'!"

  describe '#mapLocalizedAttrib', ->
    it 'should create mapping for language attributes', (done) ->
      csv =
        """
        foo,name.de,bar,name.it
        x,Hallo,y,ciao
        """
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        values = @map.mapLocalizedAttrib parsed.data[0], CONS.HEADER_NAME, @validator.header.toLanguageIndex()
        expect(_.size values).toBe 2
        expect(values['de']).toBe 'Hallo'
        expect(values['it']).toBe 'ciao'
        done()
      .catch done.fail

    it 'should fallback to non localized column', (done) ->
      csv =
        """
        foo,a1,bar
        x,hi,y
        aaa,,bbb
        """
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.header.toIndex()
        values = @map.mapLocalizedAttrib(parsed.data[0], 'a1', {})
        expect(_.size values).toBe 1
        expect(values['en']).toBe 'hi'

        values = @map.mapLocalizedAttrib(parsed.data[1], 'a1', {})
        expect(values).toBeUndefined()
        done()
      .catch done.fail

    it 'should return undefined if header can not be found', (done) ->
      csv =
        """
        foo,a1,bar
        x,hi,y
        """
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.header.toIndex()
        values = @map.mapLocalizedAttrib(parsed.data[0], 'a2', {})
        expect(values).toBeUndefined()
        done()
      .catch done.fail

  describe '#mapBaseProduct', ->
    it 'should map base product', (done) ->
      csv =
        """
        productType,id,name,variantId,key
        foo,xyz,myProduct,1,key123
        """
      pt =
        id: '123'
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.validateOffline parsed.data
        product = @map.mapBaseProduct @validator.rawProducts[0].master, pt

        expectedProduct =
          id: 'xyz'
          key: 'key123'
          productType:
            typeId: 'product-type'
            id: '123'
          name:
            en: 'myProduct'
          slug:
            en: 'myproduct'
          masterVariant: {}
          categoryOrderHints: {}
          variants: []
          categories: []

        expect(product).toEqual expectedProduct
        done()
      .catch done.fail

    it 'should map base product with categories', (done) ->
      csv =
        """
        productType,id,name,variantId,categories
        foo,xyz,myProduct,1,ext-123
        """
      pt =
        id: '123'
      cts = [
        id: '234'
        name:
          en: 'mockName'
        slug:
          en: 'mockSlug'
        externalId: 'ext-123'
      ]

      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @categories = new Categories
        @categories.buildMaps cts
        @map.categories = @categories
        @validator.validateOffline parsed.data
        product = @map.mapBaseProduct @validator.rawProducts[0].master, pt

        expectedProduct =
          id: 'xyz'
          productType:
            typeId: 'product-type'
            id: '123'
          name:
            en: 'myProduct'
          slug:
            en: 'myproduct'
          masterVariant: {}
          categoryOrderHints: {}
          variants: []
          categories: [
            typeId: 'category'
            id: '234'
          ]

        expect(product).toEqual expectedProduct
        done()
      .catch done.fail
    it 'should map search keywords', (done) ->
      csv =
      """
        productType,variantId,id,name.en,slug.en,searchKeywords.en,searchKeywords.fr-FR
        product-type,1,xyz,myProduct,myproduct,some;new;search;keywords,bruxelle;liege;brugge,
        """
      pt =
        id: '123'
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.validateOffline parsed.data
        product = @map.mapBaseProduct @validator.rawProducts[0].master, pt

        expectedProduct =
          id: 'xyz'
          productType:
            typeId: 'product-type'
            id: '123'
          name:
            en: 'myProduct'
          slug:
            en: 'myproduct'
          masterVariant: {}
          categoryOrderHints: {}
          variants: []
          categories: []
          searchKeywords: {"en":[{"text":"some"},{"text":"new"},{"text":"search"},{"text":"keywords"}],"fr-FR":[{"text":"bruxelle"},{"text":"liege"},{"text":"brugge"}]}

        expect(product).toEqual expectedProduct
        done()
      .catch done.fail

    it 'should map empty search keywords', (done) ->
      csv =
        """
        productType,variantId,id,name.en,slug.en,searchKeywords.en
        product-type,1,xyz,myProduct,myproduct,
        """
      pt =
        id: '123'
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.validateOffline parsed.data
        product = @map.mapBaseProduct @validator.rawProducts[0].master, pt

        expectedProduct =
          id: 'xyz'
          productType:
            typeId: 'product-type'
            id: '123'
          name:
            en: 'myProduct'
          slug:
            en: 'myproduct'
          masterVariant: {}
          categoryOrderHints: {}
          variants: []
          categories: []

        expect(product).toEqual expectedProduct
        done()
      .catch done.fail

  describe '#mapVariant', ->
    it 'should give feedback on bad variant id', ->
      @map.header = new Header [ 'variantId' ]
      @map.header.toIndex()
      variant = @map.mapVariant [ 'foo' ], 3, null, 7
      expect(variant).toBeUndefined()
      expect(_.size @map.errors).toBe 1
      expect(@map.errors[0]).toBe "[row 7:variantId] The number 'foo' isn't valid!"

    it 'should map variant with one attribute', ->
      productType =
        attributes: [
          { name: 'a2', type: { name: 'text' } }
        ]

      @map.header = new Header [ 'a0', 'a1', 'a2', 'sku', 'variantId', 'variantKey' ]
      @map.header.toIndex()
      variant = @map.mapVariant [ 'v0', 'v1', 'v2', 'mySKU', '9', 'vKey123' ], 9, productType, 77

      expectedVariant =
        id: 9
        sku: 'mySKU'
        key: 'vKey123'
        prices: []
        attributes: [
          name: 'a2'
          value: 'v2'
        ]
        images: []

      expect(variant).toEqual expectedVariant

    it 'should map conflicting attribute names', ->
      productType =
        name: 'prodType'
        attributes: [
          {
            name: "description"
            type: {
              name: "ltext"
            }
          }
          {
            name: "productType"
            type: {
              name: "ltext"
            }
          }
          {
            name: "createdAt"
            type: {
              name: "number"
            }
          }
          {
            name: "slug"
            type: {
              name: "text"
            }
          }
          {
            name: "name"
            type: {
              name: "ltext"
            }
          }
        ]


      @map.header = new Header [
        'productType', 'sku', 'images', 'name.en','name.de','slug.en','slug.de','attribute.description.en',
        'attribute.description.de','attribute.productType.en','attribute.productType.de',
        'attribute.createdAt','attribute.slug','attribute.name.en','attribute.name.de'
      ]
      @map.header.toIndex()
      variant = @map.mapVariant [
        'testConflict','mySKU','http://url/of/the/image;http://url/of/the/multiple/image|custom|20x20' ,'testNameEn','testNameDe','slugEn','slugDe','abcdEn','abcdDe','ptEn','ptDe','1234','slugTextAttr','nameAttrEn','nameAttrDe'
      ], 9, productType, 77

      expectedVariant =
        id: 9
        sku: 'mySKU'
        prices: []
        attributes: [
          { name: 'description', value: { en: 'abcdEn', de: 'abcdDe' } },
          { name: 'productType', value: { en: 'ptEn', de: 'ptDe' } },
          { name: 'createdAt', value: 1234 },
          { name: 'slug', value: 'slugTextAttr' },
          { name: 'name', value: { en: 'nameAttrEn', de: 'nameAttrDe' } }
        ]
        images: [
          { url: "http://url/of/the/image", label: "", dimensions: { w:0, h: 0 } },
          { url: "http://url/of/the/multiple/image", label: "custom", dimensions: { w: 20, h: 20 } }
        ]

      expect(variant).toEqual expectedVariant

    it 'should take over SameForAll contrainted attribute from master row', ->
      @map.header = new Header [ 'aSame', 'variantId' ]
      @map.header.toIndex()
      productType =
        attributes: [
          { name: 'aSame', type: { name: 'text' }, attributeConstraint: 'SameForAll' }
        ]
      product =
        masterVariant:
          attributes: [
            { name: 'aSame', value: 'sameValue' }
          ]

      variant = @map.mapVariant [ 'whatever', '11' ], 11, productType, 99, product

      expectedVariant =
        id: 11
        prices: []
        attributes: [
          name: 'aSame'
          value: 'sameValue'
        ]
        images: []

      expect(variant).toEqual expectedVariant

  describe '#mapAttribute', ->
    it 'should map simple text attribute', ->
      productTypeAttribute =
        name: 'foo'
        type:
          name: 'text'
      @map.header = new Header [ 'foo', 'bar' ]
      attribute = @map.mapAttribute [ 'some text', 'blabla' ], productTypeAttribute

      expectedAttribute =
        name: 'foo'
        value: 'some text'
      expect(attribute).toEqual expectedAttribute

    it 'should map ltext attribute', ->
      productType =
        id: 'myType'
        attributes: [
          name: 'bar'
          type:
            name: 'ltext'
        ]
      @map.header = new Header [ 'foo', 'bar.en', 'bar.es' ]
      languageHeader2Index = @map.header._productTypeLanguageIndexes productType
      attribute = @map.mapAttribute [ 'some text', 'hi', 'hola' ], productType.attributes[0], languageHeader2Index

      expectedAttribute =
        name: 'bar'
        value:
          en: 'hi'
          es: 'hola'
      expect(attribute).toEqual expectedAttribute

    it 'should map set of lext attribute', ->
      productType =
        id: 'myType'
        attributes: [
          name: 'baz'
          type:
            name: 'set'
            elementType:
              name: 'ltext'
        ]
      @map.header = new Header [ 'foo', 'baz.en', 'baz.de' ]
      languageHeader2Index = @map.header._productTypeLanguageIndexes productType
      attribute = @map.mapAttribute [ 'some text', 'foo1;foo2', 'barA;barB;barC' ], productType.attributes[0], languageHeader2Index

      expectedAttribute =
        name: 'baz'
        value: [
          {"en": "foo1", "de": "barA"},
          {"en": "foo2", "de": "barB"},
          {"de": "barC"}
        ]
      expect(attribute).toEqual expectedAttribute

    it 'should map set of money attributes', ->
      productType =
        id: 'myType'
        attributes: [
          name: 'money-rules'
          type:
            name: 'set'
            elementType:
              name: 'money'
        ]
      @map.header = new Header [ 'money-rules' ]
      languageHeader2Index = @map.header._productTypeLanguageIndexes productType
      attribute = @map.mapAttribute [ 'EUR 200;USD 100' ], productType.attributes[0], languageHeader2Index

      expectedAttribute =
        name: 'money-rules'
        value: [
          {"centAmount": 200, "currencyCode": "EUR"},
          {"centAmount": 100, "currencyCode": "USD"}
        ]
      expect(attribute).toEqual expectedAttribute

    it 'should map set of number attributes', ->
      productType =
        id: 'myType'
        attributes: [
          name: 'numbers'
          type:
            name: 'set'
            elementType:
              name: 'number'
        ]
      @map.header = new Header [ 'numbers' ]
      languageHeader2Index = @map.header._productTypeLanguageIndexes productType
      attribute = @map.mapAttribute [ '1;0;-1' ], productType.attributes[0], languageHeader2Index

      expectedAttribute =
        name: 'numbers'
        value: [ 1, 0, -1 ]
      expect(attribute).toEqual expectedAttribute

    it 'should map set of boolean attributes', ->
      productType =
        id: 'myType'
        attributes: [
          name: 'booleanAttr'
          type:
            name: 'set'
            elementType:
              name: 'boolean'
        ]
      @map.header = new Header [ 'booleanAttr' ]
      languageHeader2Index = @map.header._productTypeLanguageIndexes productType
      attribute = @map.mapAttribute [ 'true;false;1;0' ], productType.attributes[0], languageHeader2Index

      expectedAttribute =
        name: 'booleanAttr'
        value: [ true, false, true, false ]
      expect(attribute).toEqual expectedAttribute

    it 'should validate attribute value (undefined)', ->
      productTypeAttribute =
        name: 'foo'
        type:
          name: 'text'
      @map.header = new Header [ 'foo', 'bar' ]
      attribute = @map.mapAttribute [ undefined, 'blabla' ], productTypeAttribute

      expect(attribute).not.toBeDefined()

    it 'should validate attribute value (empty object)', ->
      productTypeAttribute =
        name: 'foo'
        type:
          name: 'text'
      @map.header = new Header [ 'foo', 'bar' ]
      attribute = @map.mapAttribute [ {}, 'blabla' ], productTypeAttribute

      expect(attribute).not.toBeDefined()

    it 'should validate attribute value (empty string)', ->
      productTypeAttribute =
        name: 'foo'
        type:
          name: 'text'
      @map.header = new Header [ 'foo', 'bar' ]
      attribute = @map.mapAttribute [ '', 'blabla' ], productTypeAttribute

      expect(attribute).not.toBeDefined()

  describe '#mapPrices', ->
    it 'should map single simple price', ->
      prices = @map.mapPrices 'EUR 999'
      expect(prices.length).toBe 1
      expectedPrice =
        value:
          centAmount: 999
          currencyCode: 'EUR'
      expect(prices[0]).toEqual expectedPrice

    it 'should give feedback when number part is not a number', ->
      prices = @map.mapPrices 'EUR 9.99', 7
      expect(prices.length).toBe 0
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 7:prices] Can not parse price 'EUR 9.99'!"

    it 'should give feedback when when currency and amount isnt proper separated', ->
      prices = @map.mapPrices 'EUR1', 8
      expect(prices.length).toBe 0
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 8:prices] Can not parse price 'EUR1'!"

    it 'should map price with country', ->
      prices = @map.mapPrices 'CH-EUR 700'
      expect(prices.length).toBe 1
      expectedPrice =
        value:
          centAmount: 700
          currencyCode: 'EUR'
        country: 'CH'
      expect(prices[0]).toEqual expectedPrice

    it 'should give feedback when there are problems in parsing the country info ', ->
      prices = @map.mapPrices 'CH-DE-EUR 700', 99
      expect(prices.length).toBe 0
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 99:prices] Can not parse price 'CH-DE-EUR 700'!"

    it 'should map price with customer group', ->
      @map.customerGroups =
        name2id:
          'my Group 7': 'group123'
      prices = @map.mapPrices 'GBP 0 my Group 7'
      expect(prices.length).toBe 1
      expectedPrice =
        value:
          centAmount: 0
          currencyCode: 'GBP'
        customerGroup:
          typeId: 'customer-group'
          id: 'group123'
      expect(prices[0]).toEqual expectedPrice

    it 'should map price with validFrom', ->
      prices = @map.mapPrices 'EUR 234$2001-09-11T14:00:00.000Z'
      expect(prices.length).toBe 1
      expectedPrice =
        validFrom: '2001-09-11T14:00:00.000Z'
        value:
          centAmount: 234
          currencyCode: 'EUR'
      expect(prices[0]).toEqual expectedPrice

    it 'should map price with validUntil', ->
      prices = @map.mapPrices 'EUR 1123~2001-09-11T14:00:00.000Z'
      expect(prices.length).toBe 1
      expectedPrice =
        validUntil: '2001-09-11T14:00:00.000Z'
        value:
          centAmount: 1123
          currencyCode: 'EUR'
      expect(prices[0]).toEqual expectedPrice

    it 'should map price with validFrom and validUntil', ->
      prices = @map.mapPrices 'EUR 6352$2001-09-11T14:00:00.000Z~2015-09-11T14:00:00.000Z'
      expect(prices.length).toBe 1
      expectedPrice =
        validFrom: '2001-09-11T14:00:00.000Z'
        validUntil: '2015-09-11T14:00:00.000Z'
        value:
          centAmount: 6352
          currencyCode: 'EUR'
      expect(prices[0]).toEqual expectedPrice

    it 'should give feedback that customer group does not exist', ->
      prices = @map.mapPrices 'YEN 777 unknownGroup', 5
      expect(prices.length).toBe 0
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 5:prices] Can not find customer group 'unknownGroup'!"

    it 'should map price with channel', ->
      @map.channels =
        key2id:
          retailerA: 'channelId123'
      prices = @map.mapPrices 'YEN 19999#retailerA;USD 1 #retailerA', 1234
      expect(prices.length).toBe 2
      expect(@map.errors.length).toBe 0
      expectedPrice =
        value:
          centAmount: 19999
          currencyCode: 'YEN'
        channel:
          typeId: 'channel'
          id: 'channelId123'
      expect(prices[0]).toEqual expectedPrice
      expectedPrice =
        value:
          centAmount: 1
          currencyCode: 'USD'
        channel:
          typeId: 'channel'
          id: 'channelId123'
      expect(prices[1]).toEqual expectedPrice

    it 'should give feedback that channel with key does not exist', ->
      prices = @map.mapPrices 'YEN 777 #nonExistingChannelKey', 42
      expect(prices.length).toBe 0
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 42:prices] Can not find channel with key 'nonExistingChannelKey'!"

    it 'should map price with customer group and channel', ->
      @map.customerGroups =
        name2id:
          b2bCustomer: 'group_123'
      @map.channels =
        key2id:
          'ware House-42': 'dwh_987'
      prices = @map.mapPrices 'DE-EUR 100 b2bCustomer#ware House-42'
      expect(prices.length).toBe 1
      expectedPrice =
        value:
          centAmount: 100
          currencyCode: 'EUR'
        country: 'DE'
        channel:
          typeId: 'channel'
          id: 'dwh_987'
        customerGroup:
          typeId: 'customer-group'
          id: 'group_123'
      expect(prices[0]).toEqual expectedPrice

    it 'should map price and tiers with single PriceTier', ->
      prices = @map.mapPrices 'EUR 700%EUR 650 @2500'
      expect(prices.length).toBe 1
      expectedPrice =
        value:
          centAmount: 700
          currencyCode: 'EUR'
        tiers:[{
          value:
            centAmount: 650
            currencyCode: 'EUR'
          minimumQuantity: 2500
        }]
      expect(prices[0]).toEqual expectedPrice

    it 'should map price and tiers with multiple priceTier', ->
      prices = @map.mapPrices 'EUR 900%EUR 850 @1500%EUR 800 @2500%EUR 750 @5000'
      expect(prices.length).toBe 1
      expectedPrice =
        value:
          centAmount: 900
          currencyCode: 'EUR'
        tiers:[{
          value:
            centAmount: 850
            currencyCode: 'EUR'
          minimumQuantity: 1500
        },{
          value:
            centAmount: 800
            currencyCode: 'EUR'
          minimumQuantity: 2500
        },{
          value:
            centAmount: 750
            currencyCode: 'EUR'
          minimumQuantity: 5000
        }]
      expect(prices[0]).toEqual expectedPrice

    it 'should map multiple prices', ->
      prices = @map.mapPrices 'EUR 100;UK-USD 200;YEN -999'
      expect(prices.length).toBe 3
      expectedPrice =
        value:
          centAmount: 100
          currencyCode: 'EUR'
      expect(prices[0]).toEqual expectedPrice
      expectedPrice =
        value:
          centAmount: 200
          currencyCode: 'USD'
        country: 'UK'
      expect(prices[1]).toEqual expectedPrice
      expectedPrice =
        value:
          centAmount: -999
          currencyCode: 'YEN'
      expect(prices[2]).toEqual expectedPrice

  describe '#mapTiers', ->
    it 'should map tiers with single priceTier', ->
      tiers = @map.mapTiers 'EUR 500 @1000'
      expect(tiers.length).toBe 1
      expectedTier =
        value:
          centAmount: 500
          currencyCode: 'EUR'
        minimumQuantity: 1000
      expect(tiers[0]).toEqual expectedTier

    it 'should map tiers with multiple priceTier', ->
      tiers = @map.mapTiers 'EUR 450 @2000%EUR 400 @3000%EUR 350 @4000'
      expect(tiers.length).toBe 3
      expectedTier =
        value:
          centAmount: 450
          currencyCode: 'EUR'
        minimumQuantity: 2000
      expect(tiers[0]).toEqual expectedTier
      expectedTier =
        value:
          centAmount: 400
          currencyCode: 'EUR'
        minimumQuantity: 3000
      expect(tiers[1]).toEqual expectedTier
      expectedTier =
        value:
          centAmount: 350
          currencyCode: 'EUR'
        minimumQuantity: 4000
      expect(tiers[2]).toEqual expectedTier

  describe '#mapNumber', ->
    it 'should map integer', ->
      expect(@map.mapNumber('0')).toBe 0

    it 'should map negative integer', ->
      expect(@map.mapNumber('-100')).toBe -100

    it 'should map float', ->
      expect(@map.mapNumber('0.99')).toBe 0.99

    it 'should map negative float', ->
      expect(@map.mapNumber('-13.3333')).toBe -13.3333

    it 'should fail when input is not a valid number', ->
      number = @map.mapNumber '-10e5', 'myAttrib', 4
      expect(number).toBeUndefined()
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 4:myAttrib] The number '-10e5' isn't valid!"

  describe '#mapInteger', ->
    it 'should map integer', ->
      expect(@map.mapInteger('11')).toBe 11

    it 'should not map floats', ->
      number = @map.mapInteger '-0.1', 'foo', 7
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 7:foo] The number '-0.1' isn't valid!"

  describe '#mapBoolean', ->
    it 'should map true', ->
      expect(@map.mapBoolean('true')).toBe true

    it 'should map true represented as a number', ->
      expect(@map.mapBoolean('1')).toBe true

    it 'should map false represented as a number', ->
      expect(@map.mapBoolean('0')).toBe false

    it 'should not map invalid number as a boolean', ->
      expect(@map.mapBoolean('12345', 'myAttrib', '4')).toBe undefined
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 4:myAttrib] The value '12345' isn't a valid boolean!"

    it 'should map case insensitive', ->
      expect(@map.mapBoolean('false')).toBe false
      expect(@map.mapBoolean('False')).toBe false
      expect(@map.mapBoolean('False')).toBe false

    it 'should map the empty string', ->
      expect(@map.mapBoolean('')).toBeUndefined()

    it 'should map undefined', ->
      expect(@map.mapBoolean()).toBeUndefined()

  describe '#mapReference', ->
    it 'should map a single reference', ->
      attribute =
        type:
          referenceTypeId: 'product'
      expect(@map.mapReference('123-456', attribute.type)).toEqual { id: '123-456', typeId: 'product' }

    it 'should map set of references', ->
      productType =
        id: 'myType'
        attributes: [
          name: 'refAttrName'
          type:
            name: 'set'
            elementType:
              name: 'reference'
              referenceTypeId: 'product'
        ]
      @map.header = new Header [ 'refAttrName' ]
      languageHeader2Index = @map.header._productTypeLanguageIndexes productType
      attribute = @map.mapAttribute [ '123;456' ], productType.attributes[0], languageHeader2Index
      expect(attribute).toEqual({
        name: 'refAttrName'
        value: [
          {
            id: '123',
            typeId: 'product'
          },
          {
            id: '456',
            typeId: 'product'
          }
        ]
      })

  describe '#mapProduct', ->
    it 'should map a product', (done) ->
      productType =
        id: 'myType'
        attributes: []
      csv =
        """
        productType,name,variantId,sku
        foo,myProduct,1,x
        ,,2,y
        ,,3,z
        """
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.validateOffline parsed.data
        data = @map.mapProduct @validator.rawProducts[0], productType

        expectedProduct =
          productType:
            typeId: 'product-type'
            id: 'myType'
          name:
            en: 'myProduct'
          slug:
            en: 'myproduct'
          categories: []
          masterVariant: {
            id: 1
            sku: 'x'
            prices: []
            attributes: []
            images: []
          }
          categoryOrderHints: {}
          variants: [
            { id: 2, sku: 'y', prices: [], attributes: [], images: [] }
            { id: 3, sku: 'z', prices: [], attributes: [], images: [] }
          ]

        expect(data.product).toEqual expectedProduct
        done()
      .catch done.fail

  describe '#mapCategoryOrderHints', ->

    beforeEach ->

      @exampleCategory =
        id: 'categoryId'
        name:
          en: 'myCoolCategory',
        slug:
          en: 'slug-123'
        externalId: 'myExternalId'
      # mock the categories
      @map.categories.buildMaps([
          @exampleCategory
        ])
      @productType =
        id: 'myType'
        attributes: []

      @expectedProduct =
        productType:
          typeId: 'product-type'
          id: 'myType'
        name:
          en: 'myProduct'
        slug:
          en: 'myproduct'
        categories: []
        categoryOrderHints: {
          categoryId: '0.9'
        }
        masterVariant: {
          id: 1
          sku: 'x'
          prices: []
          attributes: []
          images: []
        }
        variants: []

    it 'should should map the categoryOrderHints using a category id', (done) ->
      csv =
        """
        productType,name,variantId,sku,categoryOrderHints
        foo,myProduct,1,x,#{@exampleCategory.id}:0.9
        """
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.validateOffline parsed.data
        data = @map.mapProduct @validator.rawProducts[0], @productType

        expect(data.product).toEqual @expectedProduct
        done()
      .catch done.fail

    it 'should should map the categoryOrderHints using a category name', (done) ->
      csv =
        """
        productType,name,variantId,sku,categoryOrderHints
        foo,myProduct,1,x,#{@exampleCategory.name.en}:0.9
        """
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.validateOffline parsed.data
        data = @map.mapProduct @validator.rawProducts[0], @productType

        expect(data.product).toEqual @expectedProduct
        done()
      .catch done.fail

    it 'should should map the categoryOrderHints using a category slug', (done) ->
      csv =
        """
        productType,name,variantId,sku,categoryOrderHints
        foo,myProduct,1,x,#{@exampleCategory.slug.en}:0.9
        """
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.validateOffline parsed.data
        data = @map.mapProduct @validator.rawProducts[0], @productType

        expect(data.product).toEqual @expectedProduct
        done()
      .catch done.fail

    it 'should should map the categoryOrderHints using a category externalId', (done) ->
      csv =
        """
        productType,name,variantId,sku,categoryOrderHints
        foo,myProduct,1,x,#{@exampleCategory.externalId}:0.9
        """
      @validator.parse csv
      .then (parsed) =>
        @map.header = parsed.header
        @validator.validateOffline parsed.data
        data = @map.mapProduct @validator.rawProducts[0], @productType

        expect(data.product).toEqual @expectedProduct
        done()
      .catch done.fail
