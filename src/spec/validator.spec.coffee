Validator = require('../main').Validator

describe '#Validator', ->
  beforeEach ->
    @validator = new Validator {}

  it 'should initialize', ->
    expect(@validator).toBeDefined()
