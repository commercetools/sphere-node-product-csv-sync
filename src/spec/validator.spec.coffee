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
      errors = @validator.valHeader data
      expect(errors.length).toBe 1
      expect(errors[0]).toBe "Can't find necessary header 'variantId'"
      done()

describe '#isVariant', ->
  beforeEach ->
    @validator = new Validator()
    @validator.header2index [ @validator.HEADER_PRODUCT_TYPE, @validator.HEADER_VARIANT_ID ]

  it 'should be true for a variant', ->
    expect(@validator.isVariant ['', 2]).toBe true

  it 'should be false for a product', ->
    expect(@validator.isVariant ['myProduct', 1]).toBe false

describe '#buildProducts', ->
  beforeEach ->
    @validator = new Validator()
    @validator.header2index [ @validator.HEADER_PRODUCT_TYPE, @validator.HEADER_VARIANT_ID ]

  it 'should build one product with 2 variants', (done) ->
    csv = "productType,variantId\n
foo,1\n
,2\n
,3"

    @validator.parse csv, (data, count) =>
      errors = @validator.buildProducts _.rest data
      expect(errors.length).toBe 0
      expect(@validator.products.length).toBe 1
      expect(@validator.products[0].masterVariant).toEqual ['foo', '1']
      expect(@validator.products[0].variants.length).toBe 2
      done()

  it 'should return error if first row in not a product', (done) ->
    csv = "productType,variantId\n
,1\n
,2"

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
    csv = 'productType,variantId\nfoo,bar'
    @validator.parse csv, (data, count) =>
      expect(@validator.validate(data)).toEqual []
      done()
