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
      @validator.parse 'foo'
      .then (parsed) ->
        expect(parsed.count).toBe 1
        done()
      .fail (e) -> done(e)

    it 'should store header', (done) ->
      csv =
        """
        myHeader
        row1
        """
      @validator.parse csv
      .then =>
        expect(@validator.header).toBeDefined
        expect(@validator.header.rawHeader).toEqual ['myHeader']
        done()
      .fail (e) -> done(e)

    it 'should pass everything but the header as content to callback', (done) ->
      csv =
        """
        myHeader
        row1
        row2,foo
        """
      @validator.parse csv
      .then (parsed) ->
        expect(parsed.data.length).toBe 2
        expect(parsed.data[0]).toEqual ['row1']
        expect(parsed.data[1]).toEqual ['row2', 'foo']
        done()
      .fail (e) -> done(e)

  describe '#checkDelimiters', ->
    it 'should work if all delimiters are different', ->
      @validator = new Validator
        csvDelimiter: '#'
        csvQuote: "'"
      @validator.checkDelimiters()
      expect(_.size @validator.errors).toBe 0

    it 'should produce an error of two delimiters are the same', ->
      @validator = new Validator
        csvDelimiter: ';'
      @validator.checkDelimiters()
      expect(_.size @validator.errors).toBe 1
      expectedErrorMessage =
        '''
        Your selected delimiter clash with each other: {"csvDelimiter":";","csvQuote":"\\"","language":".","multiValue":";","categoryChildren":">"}
        '''
      expect(@validator.errors[0]).toBe expectedErrorMessage

  describe '#isVariant', ->
    beforeEach ->
      @validator.header = new Header CONS.BASE_HEADERS

    it 'should be true for a variant', ->
      expect(@validator.isVariant ['', '2'], CONS.HEADER_VARIANT_ID).toBe true

    it 'should be false for a product', ->
      expect(@validator.isVariant ['myProduct', '1']).toBe false

  describe '#isProduct', ->
    beforeEach ->
      @validator.header = new Header CONS.BASE_HEADERS

    it 'should be false for a variantId > 1 with a product type given', ->
      expect(@validator.isProduct ['foo', '2'], CONS.HEADER_VARIANT_ID).toBe false

  describe '#buildProducts', ->
    beforeEach ->

    it 'should build 2 products and their variants', (done) ->
      csv =
        """
        productType,name,variantId
        foo,n1,1
        ,,2
        ,,3
        bar,n2,1
        ,,2
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.buildProducts parsed.data, CONS.HEADER_VARIANT_ID
        expect(@validator.errors.length).toBe 0
        expect(@validator.rawProducts.length).toBe 2
        expect(@validator.rawProducts[0].master).toEqual ['foo', 'n1', '1']
        expect(@validator.rawProducts[0].variants.length).toBe 2
        expect(@validator.rawProducts[0].startRow).toBe 2
        expect(@validator.rawProducts[1].master).toEqual ['bar', 'n2', '1']
        expect(@validator.rawProducts[1].variants.length).toBe 1
        expect(@validator.rawProducts[1].startRow).toBe 5
        done()
      .fail (e) -> done(e)

    it 'should return error if row isnt a variant nor product', (done) ->
      csv =
        """
        productType,name,variantId
        myType,,1
        ,,1
        myType,,2
        ,,foo
        ,,
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.buildProducts parsed.data, CONS.HEADER_VARIANT_ID
        expect(@validator.errors.length).toBe 3
        expect(@validator.errors[0]).toBe '[row 3] Could not be identified as product or variant!'
        expect(@validator.errors[1]).toBe '[row 5] Could not be identified as product or variant!'
        expect(@validator.errors[2]).toBe '[row 6] Could not be identified as product or variant!'
        done()
      .fail (e) -> done(e)

    it 'should return error if first row isnt a product row', (done) ->
      csv =
        """
        productType,name,variantId
        foo,,2
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.buildProducts parsed.data, CONS.HEADER_VARIANT_ID
        expect(@validator.errors.length).toBe 1
        expect(@validator.errors[0]).toBe '[row 2] We need a product before starting with a variant!'
        done()
      .fail (e) -> done(e)

    it 'should build products without variantId', (done) ->
      csv =
        """
        productType,sku
        foo,123
        bar,234
        ,345
        ,456
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.buildProducts parsed.data
        expect(@validator.errors.length).toBe 0
        expect(@validator.rawProducts.length).toBe 2
        expect(@validator.rawProducts[0].master).toEqual ['foo', '123']
        expect(@validator.rawProducts[0].variants.length).toBe 0
        expect(@validator.rawProducts[0].startRow).toBe 2
        expect(@validator.rawProducts[1].master).toEqual ['bar', '234']
        expect(@validator.rawProducts[1].variants.length).toBe 2
        expect(@validator.rawProducts[1].variants[0]).toEqual ['', '345']
        expect(@validator.rawProducts[1].variants[1]).toEqual ['', '456']
        expect(@validator.rawProducts[1].startRow).toBe 3
        done()
      .fail (e) -> done(e)

  xdescribe '#valProduct', ->
    it 'should return no error', (done) ->
      csv =
        """
        productType,name,variantId
        foo,bar,bla
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.valProduct parsed.data
      .fail (e) -> done(e)

  describe '#validateOffline', ->
    it 'should return no error', (done) ->
      csv =
        """
        productType,name,variantId
        foo,bar,1
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.validateOffline parsed.data
        expect(@validator.errors).toEqual []
      .fail (e) -> done(e)
