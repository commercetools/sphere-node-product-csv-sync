_ = require('underscore')._
Mapping = require('../main').Mapping
Validator = require('../main').Validator
Header = require '../lib/header'
CONS = require '../lib/constants'

describe 'Mapping', ->
  beforeEach ->
    @validator = new Validator()
    @map = @validator.map

  describe '#constructor', ->
    it 'should initialize', ->
      expect(-> new Mapping()).toBeDefined()
      expect(@map).toBeDefined()

  describe '#ensureValidSlug', ->
    it 'should accept unique slug', ->
      expect(@map.ensureValidSlug 'foo').toBe 'foo'

    it 'should enhance duplicate slug', ->
      expect(@map.ensureValidSlug 'foo').toBe 'foo'
      expect(@map.ensureValidSlug 'foo').toMatch /foo\d{5}/

  describe '#mapLocalizedAttrib', ->
    it 'should create mapping for language attributes', ->
      csv = "
foo,name.de,bar,name.it\n
x,Hallo,y,ciao"

      @validator.parse csv, (content) =>
        values = @map.mapLocalizedAttrib content[0], CONS.HEADER_NAME, @validator.header.toLanguageIndex()
        expect(_.size values).toBe 2
        expect(values['de']).toBe 'Hallo'
        expect(values['it']).toBe 'ciao'

    it 'should fallback to non localized column', ->
      csv = "
foo,a1,bar,\n
x,hi,y"

      @validator.parse csv, (content, count) =>
        @validator.header.toIndex()
        values = @map.mapLocalizedAttrib(content[0], 'a1', {})
        expect(_.size values).toBe 1
        expect(values['en']).toBe 'hi'

    it 'should return undefined if header can not be found', ->
      csv = "
foo,a1,bar,\n
x,hi,y"

      @validator.parse csv, (content, count) =>
        @validator.header.toIndex()
        values = @map.mapLocalizedAttrib(content[0], 'a2', {})
        expect(values).toBeUndefined()

  describe '#mapBaseProduct', ->
    it 'should map base product', ->
      csv = "
productType,name,variantId,\n
foo,myProduct,1"

      pt =
        id: '123'
      @validator.parse csv, (content, count) =>
        @validator.validateOffline content
        product = @validator.map.mapBaseProduct @validator.rawProducts[0].master, pt

        expectedProduct =
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
    it 'should map variant with one attribute', ->
      productType =
        attributes: [
          name: 'a2'
          type:
            name: 'text'
        ]

      @map.header = new Header [ 'a0', 'a1', 'a2', 'sku' ]
      @map.header.toIndex()
      variant = @map.mapVariant [ 'v0', 'v1', 'v2', 'mySKU' ], 2, productType

      expectedVariant =
        id: 2
        sku: 'mySKU'
        prices: []
        attributes: [
          name: 'a2'
          value: 'v2'
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
      expect(@map.errors[0]).toBe "[row 7:prices] The number '9.99' isn't valid!"

    it 'should give feedback when number part is not a number', ->
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
      expect(@map.errors[0]).toBe "[row 99:prices] Can not extract county from price!"

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

    it 'should map muliple prices', ->
      prices = @map.mapPrices 'EUR 100;UK-USD 200;YEN 999'
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
          centAmount: 999
          currencyCode: 'YEN'
      expect(prices[2]).toEqual expectedPrice

  describe '#mapNumber', ->
    it 'should map number', ->
      expect(@validator.map.mapNumber('0')).toBe 0

    it 'should fail when input is not a valid number', ->
      number = @validator.map.mapNumber 9.99, 'myAttrib', 4
      expect(number).toBeUndefined()
      expect(@validator.map.errors.length).toBe 1
      expect(@validator.map.errors[0]).toBe "[row 4:myAttrib] The number '9.99' isn't valid!"

  describe '#mapProduct', ->
    it 'should map a product', ->
      productType =
        attributes: []
      csv = "
productType,name,variantId,sku\n
foo,myProduct,1,x\n
,,2,y\n
,,3,z\n"

      @validator.parse csv, (content, count) =>
        @validator.validateOffline content
        product = @validator.map.mapProduct @validator.rawProducts[0], productType

        expectedProduct =
          productType:
            typeId: 'product-type'
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

        expect(product).toEqual expectedProduct
