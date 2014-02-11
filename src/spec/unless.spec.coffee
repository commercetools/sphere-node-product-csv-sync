describe 'understanding unless', ->
  
  it 'with an object', ->
    expect(true unless {}).toBeUndefined()

  it 'with null', ->
    expect(true unless null).toBe true

  it 'with undefined', ->
    expect(true unless undefined).toBe true

  it 'with empty single quoted string', ->
    expect(true unless '').toBe true

  it 'with empty double quoted string', ->
    expect(true unless "").toBe true

  it 'with some string', ->
    expect(true unless "foo").toBeUndefined()

  it 'with 0', ->
    expect(true unless 0).toBe true

  it 'with 1', ->
    expect(true unless 1).toBeUndefined()

  it 'with false', ->
    expect(true unless false).toBe true

  it 'with true', ->
    expect(true unless true).toBeUndefined()
