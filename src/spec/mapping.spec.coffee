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

describe '#productTypeHeaderIndex', ->
  beforeEach ->
    @map = new Mapping()

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
  beforeEach ->
    @validator = new Validator()
    @map = new Mapping()

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
  beforeEach ->
    @validator = new Validator()

  it 'should return undefined if header can not be found', ->
    csv = "
productType,name,variantId,\n
foo,myProduct,1"
    pt =
      id: '123'
    @validator.parse csv, (data, count) =>
      @validator.validate data
      product = @validator.map.mapBaseProduct @validator.products[0].master, pt

      expectedProduct =
        productType:
          type: 'product-type'
          id: '123'
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
      product = @validator.map.mapProduct @validator.products[0], productType

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
