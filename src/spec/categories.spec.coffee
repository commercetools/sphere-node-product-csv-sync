_ = require 'underscore'
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
        { id: 1, name: { en: 'cat1' } }
        { id: 2, name: { en: 'cat2' } }
      ]
      @categories.buildMaps categories
      expect(_.size @categories.id2index).toBe 2
      expect(_.size @categories.name2id).toBe 2
      expect(_.size @categories.fqName2id).toBe 2
      expect(_.size @categories.duplicateNames).toBe 0

    it 'should create maps for children categories', ->
      categories = [
        { id: 'idx', name: { en: 'root' } }
        { id: 'idy', name: { en: 'main' }, ancestors: [ { id: 'idx' } ] }
        { id: 'idz', name: { en: 'sub' }, ancestors: [ { id: 'idx' }, { id: 'idy' } ] }
      ]
      @categories.buildMaps categories
      expect(_.size @categories.id2index).toBe 3
      expect(_.size @categories.name2id).toBe 3
      expect(_.size @categories.fqName2id).toBe 3
      expect(@categories.fqName2id['root']).toBe 'idx'
      expect(@categories.fqName2id['root>main']).toBe 'idy'
      expect(@categories.fqName2id['root>main>sub']).toBe 'idz'
      expect(_.size @categories.duplicateNames).toBe 0