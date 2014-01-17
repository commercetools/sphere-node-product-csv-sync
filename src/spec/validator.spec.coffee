_ = require('underscore')._
Validator = require('../main').Validator

describe '#Validator', ->
  beforeEach ->
    @validator = new Validator()

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
      errors = @validator.valHeader data[0]
      expect(errors.length).toBe 2
      expect(errors[0]).toBe "Can't find necessary header 'name'"
      expect(errors[1]).toBe "Can't find necessary header 'variantId'"
      done()

describe '#isVariant', ->
  beforeEach ->
    @validator = new Validator()
    @validator.header2index [ @validator.HEADER_PRODUCT_TYPE, @validator.HEADER_NAME, @validator.HEADER_VARIANT_ID ]

  it 'should be true for a variant', ->
    expect(@validator.isVariant ['', '', 2]).toBe true

  it 'should be false for a product', ->
    expect(@validator.isVariant ['myProduct', 1]).toBe false

describe '#buildProducts', ->
  beforeEach ->
    @validator = new Validator()
    @validator.header2index [ @validator.HEADER_PRODUCT_TYPE, @validator.HEADER_NAME, @validator.HEADER_VARIANT_ID ]

  it 'should build 2 products their variants', (done) ->
    csv = "productType,name,variantId\n
foo,n1,1\n
,,2\n
,,3\n
bar,n2,1\n
,,2"


    @validator.parse csv, (data, count) =>
      errors = @validator.buildProducts _.rest data
      expect(errors.length).toBe 0
      expect(@validator.products.length).toBe 2
      expect(@validator.products[0].masterVariant).toEqual ['foo', 'n1', '1']
      expect(@validator.products[0].variants.length).toBe 2
      expect(@validator.products[1].masterVariant).toEqual ['bar', 'n2', '1']
      expect(@validator.products[1].variants.length).toBe 1
      done()

  it 'should return error if first row in not a product', (done) ->
    csv = "productType,name,variantId\n
,,1\n
,,2"

    @validator.parse csv, (data, count) =>
      errors = @validator.buildProducts _.rest data
      expect(errors.length).toBe 2
      expect(errors[0]).toBe '[row 1] We need a product before starting with a variant!'
      expect(errors[1]).toBe '[row 2] We need a product before starting with a variant!'
      done()

describe '#validate', ->
  beforeEach ->
    @validator = new Validator()

  it 'should return no error', (done) ->
    csv = "productType,name,variantId\n
foo,bar,bla"
    @validator.parse csv, (data, count) =>
      expect(@validator.validate(data)).toEqual []
      done()
