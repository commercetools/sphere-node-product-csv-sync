_ = require('underscore')._
Import = require('../main').Import
CONS = require '../lib/constants'

describe 'Import', ->
  beforeEach ->
    @importer = new Import()

  describe '#constructor', ->
    it 'should initialize without options', ->
      expect(@importer).toBeDefined()
      expect(@importer.sync).not.toBeDefined()
      expect(@importer.client).not.toBeDefined()

    it 'should initialize with options', ->
      importer = new Import
        config:
          project_key: 'foo'
          client_id: 'id'
          client_secret: 'secret'
        logConfig:
          streams: [
            {level: 'warn', stream: process.stdout}
          ]
      expect(importer).toBeDefined()
      expect(importer.client).toEqual importer.sync._client
      expect(importer.client._task._maxParallel).toBe 10

  describe 'match on custom attribute', ->
    it 'should find match based on custom attribute', ->
      product =
        id: '123'
        masterVariant:
          attributes: [
            { name: 'foo', value: 'bar' }
          ]
      @importer.customAttributeNameToMatch = 'foo'

      val = @importer.getCustomAttributeValue(product.masterVariant)
      expect(val).toEqual 'bar'

      @importer.initMatcher [product]
      expect(@importer.id2index).toEqual { 123: 0 }
      expect(@importer.sku2index).toEqual {}
      expect(@importer.slug2index).toEqual {}
      expect(@importer.customAttributeValue2index).toEqual { 'bar': 0 }

      index = @importer._matchOnCustomAttribute product
      expect(index).toBe 0

      match = @importer.match
        product:
          masterVariant:
            attributes: []
          variants: [
            { attributes: [{ name: 'foo', value: 'bar' }] }
          ]
        header:
          has: -> false
          hasLanguageForBaseAttribute: -> false

      expect(match).toBe product
