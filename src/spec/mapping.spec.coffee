_ = require 'underscore'
CONS = require '../lib/constants'
{Header, Mapping, Validator} = require '../main'

describe 'Mapping', ->
  beforeEach ->
    @validator = new Validator()
    @map = @validator.map

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
    it 'should create mapping for language attributes', ->
      csv =
        """
        foo,name.de,bar,name.it
        x,Hallo,y,ciao
        """
      @validator.parse csv, (content) =>
        values = @map.mapLocalizedAttrib content[0], CONS.HEADER_NAME, @validator.header.toLanguageIndex()
        expect(_.size values).toBe 2
        expect(values['de']).toBe 'Hallo'
        expect(values['it']).toBe 'ciao'

    it 'should fallback to non localized column', ->
      csv =
        """
        foo,a1,bar
        x,hi,y
        aaa,,bbb
        """
      @validator.parse csv, (content, count) =>
        @validator.header.toIndex()
        values = @map.mapLocalizedAttrib(content[0], 'a1', {})
        expect(_.size values).toBe 1
        expect(values['en']).toBe 'hi'

        values = @map.mapLocalizedAttrib(content[1], 'a1', {})
        expect(values).toBeUndefined()

    it 'should return undefined if header can not be found', ->
      csv =
        """
        foo,a1,bar
        x,hi,y
        """
      @validator.parse csv, (content, count) =>
        @validator.header.toIndex()
        values = @map.mapLocalizedAttrib(content[0], 'a2', {})
        expect(values).toBeUndefined()

  describe '#mapBaseProduct', ->
    it 'should map base product', ->
      csv =
        """
        productType,id,name,variantId
        foo,xyz,myProduct,1
        """
      pt =
        id: '123'
      @validator.parse csv, (content, count) =>
        @validator.validateOffline content
        product = @validator.map.mapBaseProduct @validator.rawProducts[0].master, pt

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
          variants: []
          categories: []

        expect(product).toEqual expectedProduct

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

      @map.header = new Header [ 'a0', 'a1', 'a2', 'sku', 'variantId' ]
      @map.header.toIndex()
      variant = @map.mapVariant [ 'v0', 'v1', 'v2', 'mySKU', '9' ], 9, productType, 77

      expectedVariant =
        id: 9
        sku: 'mySKU'
        prices: []
        attributes: [
          name: 'a2'
          value: 'v2'
        ]
        images: []

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
          myGroup: 'group123'
      prices = @map.mapPrices 'GBP 0 myGroup'
      expect(prices.length).toBe 1
      expectedPrice =
        value:
          centAmount: 0
          currencyCode: 'GBP'
        customerGroup:
          typeId: 'customer-group'
          id: 'group123'
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
          wareHouse: 'dwh_987'
      prices = @map.mapPrices 'DE-EUR 100 b2bCustomer#wareHouse'
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

    it 'should map muliple prices', ->
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

  describe '#mapNumber', ->
    it 'should map number', ->
      expect(@validator.map.mapNumber('0')).toBe 0

    it 'should map negative number', ->
      expect(@validator.map.mapNumber('-100')).toBe -100

    it 'should fail when input is not a valid number', ->
      number = @validator.map.mapNumber '9.99', 'myAttrib', 4
      expect(number).toBeUndefined()
      expect(@validator.map.errors.length).toBe 1
      expect(@validator.map.errors[0]).toBe "[row 4:myAttrib] The number '9.99' isn't valid!"

  describe '#mapProduct', ->
    it 'should map a product', ->
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
      @validator.parse csv, (content, count) =>
        @validator.validateOffline content
        data = @validator.map.mapProduct @validator.rawProducts[0], productType

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
          variants: [
            { id: 2, sku: 'y', prices: [], attributes: [], images: [] }
            { id: 3, sku: 'z', prices: [], attributes: [], images: [] }
          ]

        expect(data.product).toEqual expectedProduct
