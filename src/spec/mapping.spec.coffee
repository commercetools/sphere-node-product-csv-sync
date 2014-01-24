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
        @map.h2i =
          a1: 1
        values = @map.mapLocalizedAttrib(content[0], 'a1', {})
        expect(_.size values).toBe 1
        expect(values['en']).toBe 'hi'

    it 'should return undefined if header can not be found', ->
      csv = "
foo,a1,bar,\n
x,hi,y"

      @validator.parse csv, (content, count) =>
        @map.h2i =
          a1: 1
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
          masterVariant: {}
          variants: []
          categories: []

        expect(product).toEqual expectedProduct

  describe '#mapVariant', ->
    it 'should map variant with one attribute', ->
      productType =
        attributes: [
          name: 'a2'
          type: 'text'
        ]

      @map.header = new Header [ 'a0', 'a1', 'a2' ]
      variant = @map.mapVariant [ 'v0', 'v1', 'v2' ], productType

      expectedVariant =
        prices: []
        attributes: [
          name: 'a2'
          value: 'v2'
        ]

      expect(variant).toEqual expectedVariant

  describe '#mapAttribute', ->
    it 'should map simple text attribute', ->
      productTypeAttribute =
        name: 'foo'
        type: 'text'
      @map.header = new Header [ 'foo', 'bar' ]
      attribute = @map.mapAttribute [ 'some text', 'blabla' ], productTypeAttribute

      expectedAttribute =
        name: 'foo'
        value: 'some text'
      expect(attribute).toEqual expectedAttribute

  describe '#mapPrices', ->
    it 'should map single simple price', ->
      prices = @map.mapPrices 'EUR 999'
      expect(prices.length).toBe 1
      expectedPrice =
        money:
          centAmount: 999
          currencyCode: 'EUR'
      expect(prices[0]).toEqual expectedPrice

    it 'should give feedback when number part is not a number', ->
      prices = @map.mapPrices 'EUR 9.99', 7
      expect(prices.length).toBe 0
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 7] The price amount '9.99' isn't valid!"

    it 'should give feedback when number part is not a number', ->
      prices = @map.mapPrices 'EUR1', 8
      expect(prices.length).toBe 0
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 8] Can not parse price 'EUR1'!"

    xit 'should map price with country', ->
      prices = @map.mapPrices 'CH-EUR 700'
      expect(prices.length).toBe 1
      expectedPrice =
        money:
          centAmount: 700
          currencyCode: 'EUR'
        country: 'CH'
      expect(prices[0]).toEqual expectedPrice

    xit 'should map price with customer group', ->
      prices = @map.mapPrices 'GBP 0.GC'
      expect(prices.length).toBe 1
      expectedPrice =
        money:
          centAmount: 0
          currencyCode: 'GBP'
        customerGroup:
          typeId: 'customer-group'
          id: 'TODO'
      expect(prices[0]).toEqual expectedPrice

    xit 'should map price with channel key', ->
      prices = @map.mapPrices 'USD 700-foobar'
      expect(prices.length).toBe 1
      expectedPrice =
        money:
          centAmount: 700
          currencyCode: 'GBP'
        channel:
          typeId: 'channel'
          id: 'TODO'
      expect(prices[0]).toEqual expectedPrice

    xit 'should map muliple prices', ->
      prices = @map.mapPrices 'EUR 100;UK-USD 200'
      expect(prices.length).toBe 2
      expectedPrice =
        money:
          centAmount: 100
          currencyCode: 'EUR'
      expect(prices[0]).toEqual expectedPrice
      expectedPrice =
        money:
          centAmount: 200
          currencyCode: 'USD'
        country: 'UK'
      expect(prices[1]).toEqual expectedPrice


  describe '#mapProduct', ->
    it 'should map a product', ->
      productType =
        attributes: []
      csv = "
productType,name,variantId\n
foo,myProduct,1\n
,,2\n
,,3\n"

      @validator.parse csv, (content, count) =>
        @validator.validateOffline content
        product = @validator.map.mapProduct @validator.rawProducts[0], productType

        expectedProduct =
          productType:
            typeId: 'product-type'
          name:
            en: 'myProduct'
          categories: []
          masterVariant: {
            prices: []
            attributes: []
          }
          variants: [
            { prices: [], attributes: [] }
            { prices: [], attributes: [] }
          ]

        expect(product).toEqual expectedProduct
