_ = require('underscore')._
Csv = require 'csv'
Variants = require '../lib/variants'

describe 'Variants', ->
  beforeEach ->
    @variants = new Variants()

  describe '#constructor', ->
    it 'should construct', ->
      expect(@variants).toBeDefined()

  describe '#groupVariants', ->
    it 'should use variantId 1 for each new product', (done) ->
      csv =
        '''
        foo,bar
        xyz,abc
        123,456
        '''
      Csv().from.string(csv).to.array (data, count) =>
        rows = @variants.groupVariants(_.rest(data), 0)
        expect(_.size rows).toBe 2
        expect(rows[1]).toEqual ['xyz', 'abc', 1]
        expect(rows[0]).toEqual ['123', '456', 1]
        done()

    it 'should set proper variantId for each detected variant', (done) ->
      csv =
        '''
        foo,bar
        x,same
        y,same
        z,same
        a,differnet
        '''
      Csv().from.string(csv).to.array (data, count) =>
        rows = @variants.groupVariants(_.rest(data), 1)
        expect(_.size rows).toBe 4
        expect(rows[0]).toEqual ['x', 'same', 1]
        expect(rows[1]).toEqual ['y', 'same', 2]
        expect(rows[2]).toEqual ['z', 'same', 3]
        expect(rows[3]).toEqual ['a', 'differnet', 1]
        done()
