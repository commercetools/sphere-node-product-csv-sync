_ = require 'underscore'
_.mixin require('underscore-mixins')
CONS =  require '../lib/constants'
{Header, Validator} = require '../lib/main'

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
      .catch (err) -> done _.prettify(err)

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
      .catch (err) -> done _.prettify(err)

    it 'should trim csv cells', (done) ->
      csv =
        """
        myHeader ,name
        row1,name1
        """
      @validator.parse csv
      .then =>
        expect(@validator.header).toBeDefined
        expect(@validator.header.rawHeader).toEqual ['myHeader', 'name']
        done()
      .catch (err) -> done _.prettify(err)

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
      .catch (err) -> done _.prettify(err)

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

  describe '#buildProducts', ->
    beforeEach ->

    it 'should build 2 products and their variants', (done) ->
      csv =
        """
        productType,key,variantId
        foo,key-12,1
        ,,2
        ,,3
        bar,key-56,1
        ,,2
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.buildProducts parsed.data, CONS.HEADER_VARIANT_ID
        expect(@validator.errors.length).toBe 0
        expect(@validator.rawProducts.length).toBe 2
        expect(@validator.rawProducts[0].master).toEqual ['foo', 'key-12', '1']
        expect(@validator.rawProducts[0].variants.length).toBe 2
        expect(@validator.rawProducts[0].startRow).toBe 2
        expect(@validator.rawProducts[1].master).toEqual ['bar', 'key-56', '1']
        expect(@validator.rawProducts[1].variants.length).toBe 1
        expect(@validator.rawProducts[1].startRow).toBe 5
        done()
      .catch (err) -> done _.prettify(err)

    it 'should return error if row isnt a variant nor product', (done) ->
      csv =
        """
        productType,key,variantId
        myType,key-12,1
        ,,1
        myType,key-56,2
        ,,foo
        ,,
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.buildProducts parsed.data, CONS.HEADER_VARIANT_ID
        expect(@validator.errors.length).toBe 2
        expect(@validator.errors[0]).toBe '[row 5] Could not be identified as product or variant!'
        expect(@validator.errors[1]).toBe '[row 6] Could not be identified as product or variant!'
        done()
      .catch (err) -> done _.prettify(err)

    it 'should not return error if first row (masterVariant) is not 1', (done) ->
      csv =
        """
        productType,key,variantId
        foo,key-12,3
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.buildProducts parsed.data, CONS.HEADER_VARIANT_ID
        expect(@validator.errors.length).toBe 0
        expect(@validator.rawProducts.length).toBe 1
        expect(@validator.rawProducts[0].master).toEqual ['foo', 'key-12', '3']
        expect(@validator.rawProducts[0].variants.length).toBe 0
        done()
      .catch (err) -> done _.prettify(err)

    it 'should not build separate products without filled rows', (done) ->
      csv =
        """
        productType,key,variantId
        foo,key-12,3
        ,,1
        ,,5
        bar,key-56,2
        ,,9
        ,,4
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.buildProducts parsed.data, CONS.HEADER_VARIANT_ID
        expect(@validator.errors.length).toBe 0
        expect(@validator.rawProducts.length).toBe 2
        expect(@validator.rawProducts[0].master).toEqual ['foo', 'key-12', '3']
        expect(@validator.rawProducts[0].variants.length).toBe 2
        expect(@validator.rawProducts[0].variants[0].variant).toEqual ['', '', '1']
        expect(@validator.rawProducts[0].variants[1].variant).toEqual ['', '', '5']
        expect(@validator.rawProducts[0].startRow).toBe 2
        expect(@validator.rawProducts[1].master).toEqual ['bar', 'key-56', '2']
        expect(@validator.rawProducts[1].variants.length).toBe 2
        expect(@validator.rawProducts[1].variants[0].variant).toEqual ['', '', '9']
        expect(@validator.rawProducts[1].variants[1].variant).toEqual ['', '', '4']
        expect(@validator.rawProducts[1].startRow).toBe 5
        done()
      .catch (err) -> done _.prettify(err)

    it 'should not build separate products with filled rows', (done) ->
      csv =
        """
        productType,key,variantId
        foo,key-12,3
        foo,key-12,1
        foo,key-12,5
        bar,key-56,2
        bar,key-56,4
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.buildProducts parsed.data, CONS.HEADER_VARIANT_ID
        expect(@validator.errors.length).toBe 0
        expect(@validator.rawProducts.length).toBe 2
        expect(@validator.rawProducts[0].master).toEqual ['foo', 'key-12', '3']
        expect(@validator.rawProducts[0].variants.length).toBe 2
        expect(@validator.rawProducts[0].variants[0].variant).toEqual ['foo', 'key-12', '1']
        expect(@validator.rawProducts[0].variants[1].variant).toEqual ['foo', 'key-12', '5']
        expect(@validator.rawProducts[0].startRow).toBe 2
        expect(@validator.rawProducts[1].master).toEqual ['bar', 'key-56', '2']
        expect(@validator.rawProducts[1].variants.length).toBe 1
        expect(@validator.rawProducts[1].variants[0].variant).toEqual ['bar', 'key-56', '4']
        expect(@validator.rawProducts[1].startRow).toBe 5
        done()
      .catch (err) -> done _.prettify(err)

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
        expect(@validator.rawProducts[1].variants[0].variant).toEqual ['', '345']
        expect(@validator.rawProducts[1].variants[1].variant).toEqual ['', '456']
        expect(@validator.rawProducts[1].startRow).toBe 3
        done()
      .catch (err) -> done _.prettify(err)

    # TODO: deprecated test. should be updated
    xit 'should build products per product type - sku update', (done) ->
      csv =
        """
        productType,sku
        foo,123
        bar,234
        bar,345
        foo,456
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.updateVariantsOnly = true
        @validator.buildProducts parsed.data
        expect(@validator.errors.length).toBe 0
        expect(@validator.rawProducts.length).toBe 2
        expect(@validator.rawProducts[0].variants.length).toBe 2
        expect(@validator.rawProducts[0].startRow).toBe 2
        expect(@validator.rawProducts[0].variants[0].variant).toEqual ['foo', '123']
        expect(@validator.rawProducts[0].variants[0].rowIndex).toBe 2
        expect(@validator.rawProducts[0].variants[1].variant).toEqual ['foo', '456']
        expect(@validator.rawProducts[0].variants[1].rowIndex).toBe 5
        expect(@validator.rawProducts[1].variants.length).toBe 2
        expect(@validator.rawProducts[1].variants[0].variant).toEqual ['bar', '234']
        expect(@validator.rawProducts[1].variants[0].rowIndex).toBe 3
        expect(@validator.rawProducts[1].variants[1].variant).toEqual ['bar', '345']
        expect(@validator.rawProducts[1].variants[1].rowIndex).toBe 4
        expect(@validator.rawProducts[1].startRow).toBe 3
        done()
      .catch (err) -> done _.prettify(err)

    it 'should use a previous productType if it is missing when doing sku update', (done) ->
      csv =
        """
        productType,sku
        foo,123
        bar,234
        ,345
        foo,456
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.updateVariantsOnly = true
        @validator.buildProducts parsed.data
        expect(@validator.errors.length).toBe 0
        expect(_.size(@validator.rawProducts)).toBe 4
        expect(@validator.rawProducts[2].master).toEqual ["bar", "345"]
        done()
      .catch (err) -> done _.prettify(err)

  xdescribe '#valProduct', ->
    it 'should return no error', (done) ->
      csv =
        """
        productType,name.en,variantId
        foo,bar,bla
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.valProduct parsed.data
        done()
      .catch (err) -> done _.prettify(err)

  describe '#validateOffline', ->
    it 'should return no error', (done) ->
      csv =
        """
        productType,key,variantId
        foo,key-123,1
        """
      @validator.parse csv
      .then (parsed) =>
        @validator.validateOffline parsed.data
        expect(@validator.errors).toEqual []
        done()
      .catch (err) -> done _.prettify(err)
