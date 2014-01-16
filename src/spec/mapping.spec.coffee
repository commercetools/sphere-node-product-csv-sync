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
