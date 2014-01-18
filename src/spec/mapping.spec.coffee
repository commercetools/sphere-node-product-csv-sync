_ = require('underscore')._
Mapping = require('../main').Mapping
Validator = require('../main').Validator
CONS = require '../lib/constants'

describe '#Mapping', ->
  beforeEach ->
    @map = new Mapping()

  it 'should initialize', ->
    expect(@map).toBeDefined()

describe '#header2index', ->
  beforeEach ->
    @validator = new Validator()
    @map = new Mapping()

  it 'should create mapping', ->
    csv = 'productType,foo,variantId\n1,2,3'
    @validator.parse csv, (data, count) =>
      h2i = @map.header2index(data[0])
      expect(_.size h2i).toBe 3
      expect(h2i['productType']).toBe 0
      expect(h2i['foo']).toBe 1
      expect(h2i['variantId']).toBe 2

describe '#languageHeader2Index', ->
  beforeEach ->
    @validator = new Validator()
    @map = new Mapping()

  it 'should create mapping for language attributes', ->
    csv = 'foo,a1.de,bar,a1.it'
    @validator.parse csv, (data, count) =>
      lang_h2i = @map.languageHeader2Index(data[0], ['a1'])
      expect(_.size lang_h2i).toBe 1
      expect(_.size lang_h2i['a1']).toBe 2
      expect(lang_h2i['a1']['de']).toBe 1
      expect(lang_h2i['a1']['it']).toBe 3

describe '#mapLocalizedAttrib', ->
  beforeEach ->
    @validator = new Validator()
    @map = new Mapping()

  it 'should create mapping for language attributes', ->
    csv = "
foo,a1.de,bar,a1.it\n
x,Hallo,y,ciao"
    @validator.parse csv, (data, count) =>
      lang_h2i = @map.languageHeader2Index(data[0], ['a1'])
      @map.lang_h2i = lang_h2i
      values = @map.mapLocalizedAttrib(data[1], 'a1')
      expect(_.size values).toBe 2
      expect(values['de']).toBe 'Hallo'
      expect(values['it']).toBe 'ciao'

  it 'should fallback to non localized column', ->
    csv = "
foo,a1,bar,\n
x,hi,y"
    @validator.parse csv, (data, count) =>
      @map.lang_h2i = {}
      @map.h2i =
        a1: 1
      values = @map.mapLocalizedAttrib(data[1], 'a1')
      expect(_.size values).toBe 1
      expect(values['en']).toBe 'hi'

  it 'should return undefined if header can not be found', ->
    csv = "
foo,a1,bar,\n
x,hi,y"
    @validator.parse csv, (data, count) =>
      @map.lang_h2i = {}
      @map.h2i =
        a1: 1
      values = @map.mapLocalizedAttrib(data[1], 'a2')
      expect(values).toBeUndefined()

describe '#mapBaseProduct', ->
  beforeEach ->
    @validator = new Validator()
    @map = new Mapping()

  it 'should return undefined if header can not be found', ->
    csv = "
productType,name,variantId,\n
foo,myProduct,1"
    @validator.parse csv, (data, count) =>
      @validator.validate data
      @map.h2i = @validator.h2i
      @map.lang_h2i = @map.languageHeader2Index(@validator.header, CONS.BASE_LOCALIZED_HEADERS)
      product = @map.mapBaseProduct @validator.products[0].master, @validator.header

      expectedProduct =
        productType:
          type: 'product-type'
        name:
          en: 'myProduct'
        masterVariant: {}
        variants: []
        categories: []

      expect(product).toEqual expectedProduct

describe '#mapVariant', ->
  beforeEach ->
    @validator = new Validator()
    @map = new Mapping()

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
  beforeEach ->
    @validator = new Validator()
    @map = new Mapping()

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

describe '#mapProduct', ->
  beforeEach ->
    @validator = new Validator()
    @map = new Mapping()

  it 'should map a product', ->
    productType =
      attributes: []
    csv = "
productType,name,variantId\n
foo,myProduct,1\n
,,2\n
,,3\n"
    @validator.parse csv, (data, count) =>
      @validator.validate data
      @map.h2i = @validator.h2i
      @map.lang_h2i = @map.languageHeader2Index(@validator.header, CONS.BASE_LOCALIZED_HEADERS)
      product = @map.mapProduct @validator.products[0], productType

      expectedProduct =
        productType:
          type: 'product-type'
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
