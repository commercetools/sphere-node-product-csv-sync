_ = require('underscore')._
Mapping = require('../main').Mapping
Validator = require('../main').Validator
CONS = require '../lib/constants'

describe 'Mapping', ->
  beforeEach ->
    @validator = new Validator()
    @map = new Mapping(validator: @validator)

  describe '#constructor', ->
    it 'should initialize', ->
      expect(@map).toBeDefined()

  describe '#header2index', ->
    it 'should create mapping', ->
      csv = 'productType,foo,variantId\n1,2,3'
      @validator.parse csv, (data, count) =>
        h2i = @map.header2index(data[0])
        expect(_.size h2i).toBe 3
        expect(h2i['productType']).toBe 0
        expect(h2i['foo']).toBe 1
        expect(h2i['variantId']).toBe 2

  describe '#languageHeader2Index', ->
    it 'should create mapping for language attributes', ->
      csv = 'foo,a1.de,bar,a1.it'
      @validator.parse csv, (data, count) =>
        lang_h2i = @map.languageHeader2Index(data[0], ['a1'])
        expect(_.size lang_h2i).toBe 1
        expect(_.size lang_h2i['a1']).toBe 2
        expect(lang_h2i['a1']['de']).toBe 1
        expect(lang_h2i['a1']['it']).toBe 3

  describe '#productTypeHeaderIndex', ->
    it 'should create language header index for ltext attributes', ->
      productType =
        id: '213'
        attributes: [
          name: 'foo'
          type: 'ltext'
        ]
      @map.header = ['name', 'foo.en', 'foo.de']
      lang_h2i = @map.productTypeHeaderIndex productType
      expect(_.size lang_h2i).toBe 1
      expect(_.size lang_h2i['foo']).toBe 2
      expect(lang_h2i['foo']['de']).toBe 2
      expect(lang_h2i['foo']['en']).toBe 1
      expect(@map.productTypeId2HeaderIndex).toBeDefined()
      expect(_.size @map.productTypeId2HeaderIndex).toBe 1
      expect(@map.productTypeId2HeaderIndex['213']['foo']).toEqual lang_h2i['foo']

  describe '#mapLocalizedAttrib', ->
    it 'should create mapping for language attributes', ->
      csv = "
foo,a1.de,bar,a1.it\n
x,Hallo,y,ciao"

      @validator.parse csv, (data, count) =>
        lang_h2i = @map.languageHeader2Index(data[0], ['a1'])
        values = @map.mapLocalizedAttrib(data[1], 'a1', lang_h2i)
        expect(_.size values).toBe 2
        expect(values['de']).toBe 'Hallo'
        expect(values['it']).toBe 'ciao'

    it 'should fallback to non localized column', ->
      csv = "
foo,a1,bar,\n
x,hi,y"

      @validator.parse csv, (data, count) =>
        @map.h2i =
          a1: 1
        values = @map.mapLocalizedAttrib(data[1], 'a1', {})
        expect(_.size values).toBe 1
        expect(values['en']).toBe 'hi'

    it 'should return undefined if header can not be found', ->
      csv = "
foo,a1,bar,\n
x,hi,y"

      @validator.parse csv, (data, count) =>
        @map.h2i =
          a1: 1
        values = @map.mapLocalizedAttrib(data[1], 'a2', {})
        expect(values).toBeUndefined()

  describe '#mapBaseProduct', ->
    it 'should map base product', ->
      csv = "
productType,name,variantId,\n
foo,myProduct,1"

      pt =
        id: '123'
      @validator.parse csv, (data, count) =>
        @validator.validateOffline data
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

      @map.h2i =
        a2: 2
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
      @map.h2i = @map.header2index [ 'foo', 'bar' ]
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

      @validator.parse csv, (data, count) =>
        @validator.validateOffline data
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
