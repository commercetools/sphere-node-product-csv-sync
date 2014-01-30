_ = require('underscore')._
Categories = require '../lib/categories'

describe 'Categories', ->
  beforeEach ->
    @categories = new Categories()

  describe '#constructor', ->
    it 'should construct', ->
      expect(@categories).toBeDefined()

  describe '#buildMaps', ->
    it 'should create maps for root categories', ->
      categories = [
        { id: 1, name: 'cat1' }
        { id: 2, name: 'cat2' }
      ]
      @categories.buildMaps categories
      expect(_.size @categories.id2index).toBe 2
      expect(_.size @categories.name2id).toBe 2
      expect(_.size @categories.fqName2id).toBe 2
      expect(_.size @categories.duplicateNames).toBe 0

    it 'should create maps for children categories', ->
      categories = [
        { id: 'idx', name: 'cat1' }
        { id: 'idy', name: 'cat2', ancestors: [ { id: 'idx' } ] }
        { id: 'idz', name: 'cat3', ancestors: [ { id: 'idy' }, { id: 'idx' } ] }
      ]
      @categories.buildMaps categories
      expect(_.size @categories.id2index).toBe 3
      expect(_.size @categories.name2id).toBe 3
      expect(_.size @categories.fqName2id).toBe 3
      expect(@categories.fqName2id['cat1']).toBe 'idx'
      expect(@categories.fqName2id['cat1>cat2']).toBe 'idy'
      expect(@categories.fqName2id['cat1>cat2>cat3']).toBe 'idz'
      expect(_.size @categories.duplicateNames).toBe 0