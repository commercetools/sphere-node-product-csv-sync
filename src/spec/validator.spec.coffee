_ = require('underscore')._
Validator = require('../main').Validator
Header = require '../lib/header'
CONS =  require '../lib/constants'

describe 'Validator', ->
  beforeEach ->
    @validator = new Validator()

  describe '@constructor', ->
    it 'should initialize', ->
      expect(@validator).toBeDefined()

  describe '#parse', ->
    it 'should parse string', (done) ->
      @validator.parse 'foo', (data, count) ->
        expect(count).toBe 1
        done()

    it 'should store header', (done) ->
      csv = "
myHeader\n
row1\n
"
      @validator.parse csv, =>
        expect(@validator.header).toBeDefined
        expect(@validator.header.rawHeader).toEqual ['myHeader']
        done()

    it 'should pass rest as content to callback', (done) ->
      csv = "
myHeader\n
row1\n
row2,foo
"
      @validator.parse csv, (content) ->
        expect(content.length).toBe 2
        expect(content[0]).toEqual ['row1']
        expect(content[1]).toEqual ['row2', 'foo']
        done()

  describe '#isVariant', ->
    beforeEach ->
      @validator.header = new Header CONS.BASE_HEADERS

    it 'should be true for a variant', ->
      expect(@validator.isVariant ['', '', 2]).toBe true

    it 'should be false for a product', ->
      expect(@validator.isVariant ['myProduct', 1]).toBe false

  describe '#buildProducts', ->
    beforeEach ->

    it 'should build 2 products their variants', (done) ->
      csv = "
productType,name,variantId\n
foo,n1,1\n
,,2\n
,,3\n
bar,n2,1\n
,,2"

      @validator.parse csv, (content) =>
        @validator.buildProducts content
        expect(@validator.errors.length).toBe 0
        expect(@validator.rawProducts.length).toBe 2
        expect(@validator.rawProducts[0].master).toEqual ['foo', 'n1', '1']
        expect(@validator.rawProducts[0].variants.length).toBe 2
        expect(@validator.rawProducts[0].startRow).toBe 1
        expect(@validator.rawProducts[1].master).toEqual ['bar', 'n2', '1']
        expect(@validator.rawProducts[1].variants.length).toBe 1
        expect(@validator.rawProducts[1].startRow).toBe 4
        done()

    it 'should return error if first row in not a product', (done) ->
      csv = "
productType,name,variantId\n
,,1\n
,,2"

      @validator.parse csv, (content) =>
        @validator.buildProducts content
        expect(@validator.errors.length).toBe 2
        expect(@validator.errors[0]).toBe '[row 1] We need a product before starting with a variant!'
        expect(@validator.errors[1]).toBe '[row 2] We need a product before starting with a variant!'
        done()

  describe '#validateOffline', ->
    it 'should return no error', ->
      csv = "
productType,name,variantId\n
foo,bar,bla"

      @validator.parse csv, (content) =>
        @validator.validateOffline content
        expect(@validator.errors).toEqual []
