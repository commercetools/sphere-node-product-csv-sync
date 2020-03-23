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
        { id: 1, name: { en: 'cat1' }, slug: { en: 'cat-1'}, key: "test 1" }
        { id: 2, name: { en: 'cat2' }, slug: { en: 'cat-2'}, key: "test 2"  }
      ]
      @categories.buildMaps categories
      expect(_.size @categories.id2index).toBe 2
      expect(_.size @categories.name2id).toBe 2
      expect(_.size @categories.fqName2id).toBe 2
      expect(_.size @categories.key2Id).toBe 2
      expect(_.size @categories.duplicateNames).toBe 0

    it 'should create maps for children categories', ->
      categories = [
        { id: 'idx', name: { en: 'root' }, slug: { en: 'root'} }
        { id: 'idy', name: { en: 'main' }, ancestors: [ { id: 'idx' } ], slug: { en: 'main'} }
        { id: 'idz', name: { en: 'sub' }, ancestors: [ { id: 'idx' }, { id: 'idy' } ], slug: { en: 'sub'} }
      ]
      @categories.buildMaps categories
      expect(_.size @categories.id2index).toBe 3
      expect(_.size @categories.name2id).toBe 3
      expect(_.size @categories.fqName2id).toBe 3
      expect(@categories.fqName2id['root']).toBe 'idx'
      expect(@categories.fqName2id['root>main']).toBe 'idy'
      expect(@categories.fqName2id['root>main>sub']).toBe 'idz'
      expect(_.size @categories.duplicateNames).toBe 0

    it 'should create maps for categories with externalId', ->
      categories = [
        { id: 'idx', name: { en: 'root' }, externalId: '123', slug: { en: 'root'}, key: "test 1" }
        { id: 'idy', name: { en: 'main' }, externalId: '234', slug: { en: 'main'}, key: "test 2" }
        { id: 'idz', name: { en: 'sub' }, externalId: '345', slug: { en: 'sub'} }
      ]
      @categories.buildMaps categories
      expect(_.size @categories.id2index).toBe 3
      expect(_.size @categories.name2id).toBe 3
      expect(_.size @categories.fqName2id).toBe 3
      expect(_.size @categories.key2Id).toBe 2
      expect(_.size @categories.externalId2id).toBe 3
      expect(@categories.externalId2id['123']).toBe 'idx'
      expect(@categories.externalId2id['234']).toBe 'idy'
      expect(@categories.externalId2id['345']).toBe 'idz'
      expect(_.size @categories.duplicateNames).toBe 0
