_ = require 'underscore'
CONS = require '../lib/constants'
{Import} = require '../lib/main'

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
        # logConfig:
        #   streams: [
        #     {level: 'warn', stream: process.stdout}
        #   ]
      expect(importer).toBeDefined()
      expect(importer.client).toBeDefined()
      expect(importer.client._task._maxParallel).toBe 10
      expect(importer.sync).toBeDefined()

  xdescribe 'match on custom attribute', ->
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

  describe 'mapVariantsBasedOnSKUs', ->
    beforeEach ->
      @header = {}
    it 'should map masterVariant', ->
      existingProducts = [
        { masterVariant: { id: 1, sku: "mySKU" }, variants: [] }
      ]
      #@importer.initMatcher existingProducts
      entry =
        product:
          masterVariant: { sku: "mySKU", attributes: [ { foo: 'bar' } ] }
      productsToUpdate = @importer.mapVariantsBasedOnSKUs(existingProducts, [entry])
      expect(_.size productsToUpdate).toBe 1
      product = productsToUpdate[0].product
      expect(product.masterVariant).toBeDefined()
      expect(product.masterVariant.id).toBe 1
      expect(product.masterVariant.sku).toBe 'mySKU'
      expect(_.size product.variants).toBe 0
      expect(product.masterVariant.attributes).toEqual [{ foo: 'bar' }]

    xit 'should map several variants into one product', ->
      existingProducts = [
        { masterVariant: { id: 1, sku: "mySKU" }, variants: [] }
        { masterVariant: { id: 1, sku: "mySKU1" }, variants: [
          { id: 2, sku: "mySKU2", attributes: [ { foo: 'bar' } ] }
          { id: 4, sku: "mySKU4", attributes: [ { foo: 'baz' } ] }
        ] }
      ]
      #@importer.initMatcher existingProducts
      entry =
        product:
          variants: [
            { sku: "mySKU4", attributes: [ { foo: 'bar4' } ] }
            { sku: "mySKU2", attributes: [ { foo: 'bar2' } ] }
            { sku: "mySKU3", attributes: [ { foo: 'bar3' } ] }
          ]
      productsToUpdate = @importer.mapVariantsBasedOnSKUs(existingProducts, [entry])
      expect(_.size productsToUpdate).toBe 1
      product = productsToUpdate[0].product
      expect(product.masterVariant.id).toBe 1
      expect(product.masterVariant.sku).toBe 'mySKU1'
      expect(_.size product.variants).toBe 2
      expect(product.variants[0].id).toBe 2
      expect(product.variants[0].sku).toBe 'mySKU2'
      expect(product.variants[0].attributes).toEqual [ { foo: 'bar2' } ]
      expect(product.variants[1].id).toBe 4
      expect(product.variants[1].attributes).toEqual [ { foo: 'bar4' } ]
