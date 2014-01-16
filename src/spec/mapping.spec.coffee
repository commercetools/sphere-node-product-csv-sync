_ = require('underscore')._
Mapping = require('../main').Mapping

describe '#Mapping', ->
  beforeEach ->
    @map = new Mapping()

  it 'should initialize', ->
    expect(@map).toBeDefined()

describe 'header2index', ->
  beforeEach ->
    @map = new Mapping()

  it 'should create mapping', ->
    h2i = @map.header2index(['a', 'b'])
    expect(_.size h2i).toBe 2
    expect(h2i['a']).toBe 0
    expect(h2i['b']).toBe 1

