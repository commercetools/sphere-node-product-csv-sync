_ = require('underscore')._
Import = require('../main').Import
CONS = require '../lib/constants'

describe 'Import', ->
  beforeEach ->
    @import = new Import({})

  describe '#constructor', ->
    it 'should initialize', ->
      expect(-> new Import()).toBeDefined()
      expect(@import).toBeDefined()

  describe 'match on custom attribute', ->
    it 'should find match based on custom attribute', ->
      product =
        id: '123'
        masterVariant:
          attributes: [
            { name: 'foo', value: 'bar' }
          ]
      @import.customAttributeNameToMatch = 'foo'
      
      val = @import.getCustomAttributeValue(product.masterVariant)
      expect(val).toEqual 'bar'

      @import.initMatcher [product]
      expect(@import.id2index).toEqual { 123: 0 }
      expect(@import.sku2index).toEqual {}
      expect(@import.slug2index).toEqual {}
      expect(@import.customAttributeValue2index).toEqual { 'bar': 0 }

      index = @import._matchOnCustomAttribute product
      expect(index).toBe 0
      
      match = @import.match
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
