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

describe '#validate', ->
  beforeEach ->
    @validator = new Validator()

  it 'should no error', (done) ->
    csv = 'productType,variantId\n1,2'
    @validator.parse csv, (data, count) =>
      expect(@validator.validate(data)).toEqual []
      done()
