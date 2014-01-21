_ = require('underscore')._
Validator = require('../main').Validator
CONS =  require '../lib/constants'

describe 'Validator', ->
  beforeEach ->
    @validator = new Validator()

  describe '@constructor', ->
    it 'should initialize', ->
      expect(@validator).toBeDefined()

  describe '#parse', ->
    beforeEach ->
      @validator = new Validator()

    it 'should parse string', (done) ->
      @validator.parse 'foo', (data, count) ->
        expect(count).toBe 1
        done()

  describe '#valHeader', ->
    beforeEach ->
      @validator = new Validator()

    it 'should return error for each missing header', (done) ->
      @validator.parse 'foo,productType\n1,2', (data, count) =>
        @validator.valHeader data[0]
        expect(@validator.errors.length).toBe 2
        expect(@validator.errors[0]).toBe "Can't find necessary base header 'name'!"
        expect(@validator.errors[1]).toBe "Can't find necessary base header 'variantId'!"
        done()

    it 'should return error on duplicate header', (done) ->
      @validator.parse 'productType,name,variantId,name\n1,2,3,4', (data, count) =>
        @validator.valHeader data[0]
        expect(@validator.errors.length).toBe 1
        expect(@validator.errors[0]).toBe "There are duplicate header entries!"
        done()

  describe '#isVariant', ->
    beforeEach ->
      @validator = new Validator()
      @validator.header2index CONS.BASE_HEADERS

    it 'should be true for a variant', ->
      expect(@validator.isVariant ['', '', 2]).toBe true

    it 'should be false for a product', ->
      expect(@validator.isVariant ['myProduct', 1]).toBe false

  describe '#buildProducts', ->
    beforeEach ->
      @validator = new Validator()
      @validator.header2index CONS.BASE_HEADERS

    it 'should build 2 products their variants', (done) ->
      csv = "
productType,name,variantId\n
foo,n1,1\n
,,2\n
,,3\n
bar,n2,1\n
,,2"

      @validator.parse csv, (data, count) =>
        @validator.buildProducts _.rest data
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

      @validator.parse csv, (data, count) =>
        @validator.buildProducts _.rest data
        expect(@validator.errors.length).toBe 2
        expect(@validator.errors[0]).toBe '[row 1] We need a product before starting with a variant!'
        expect(@validator.errors[1]).toBe '[row 2] We need a product before starting with a variant!'
        done()

  describe '#validateOffline', ->
    beforeEach ->
      @validator = new Validator()

    it 'should return no error', ->
      csv = "
productType,name,variantId\n
foo,bar,bla"

      @validator.parse csv, (data, count) =>
        @validator.validateOffline(data)
        expect(@validator.errors).toEqual []
