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
    it 'should do1', (done) ->
      csv =
        '''
        foo,bar
        xyz,abc
        '''
      Csv().from.string(csv).to.array (data, count) =>
        rows = @variants.groupVariants(_.rest(data), 0)
        expect(_.size rows).toBe 1
        expect(rows[0]).toEqual ['xyz', 'abc', 1]
        done()

    it 'should do2', (done) ->
      csv =
        '''
        foo,bar
        x,1
        y,1
        '''
      Csv().from.string(csv).to.array (data, count) =>
        rows = @variants.groupVariants(_.rest(data), 1)
        expect(_.size rows).toBe 2
        expect(rows[0]).toEqual ['x', '1', 1]
        expect(rows[1]).toEqual ['y', '1', 2]
        done()
