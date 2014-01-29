_ = require('underscore')._
Types = require '../lib/types'

describe 'Types', ->
  beforeEach ->
    @types = new Types()

  describe '#constructor', ->
    it 'should construct', ->
      expect(@types).toBeDefined()

  describe '#buildMaps', ->
    it 'should create maps for product types', ->
      pt1 =
        id: 'pt1'
        name: 'myType'
      pt2 =
        id: 'pt2'
        name: 'myType2'
      pt3 =
        id: 'pt3'
        name: 'myType'
      @types.buildMaps [pt1, pt2, pt3]
      expect(_.size @types.id2index).toBe 3
      expect(@types.id2index['pt1']).toBe 0
      expect(@types.id2index['pt2']).toBe 1
      expect(@types.id2index['pt3']).toBe 2
      expect(@types.name2id['myType']).toBe 'pt3'
      expect(@types.name2id['myType2']).toBe 'pt2'
      expect(_.size @types.duplicateNames).toBe 1
      expect(@types.duplicateNames[0]).toBe 'myType'