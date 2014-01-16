_ = require('underscore')._
Mapping = require('../main').Mapping
Validator = require('../main').Validator

describe '#Mapping', ->
  beforeEach ->
    @map = new Mapping()

  it 'should initialize', ->
    expect(@map).toBeDefined()

describe 'header2index', ->
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

describe 'languageHeader2Index', ->
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

describe 'mapLocalizedAttrib', ->
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

  it 'should create fallback to non localized column', ->
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
