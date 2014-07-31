_ = require 'underscore'
Import = require '../../lib/import'
Config = require '../../config'
TestHelpers = require './testhelpers'

jasmine.getEnv().defaultTimeoutInterval = 60000

performAllProducts = -> true

describe 'State integration tests', ->
  beforeEach (done) ->
    @importer = new Import Config
    @client = @importer.client

    unique = new Date().getTime()
    @productType =
      name: "myStateType#{unique}"
      description: 'foobar'
      attributes: [
        { name: 'myStateAttrib', label: { name: 'myStateAttrib' }, type: { name: 'text'}, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
      ]

    TestHelpers.setupProductType(@client, @productType).then (result) =>
      @productType = result
      done()
    .fail (err) ->
      done(_.prettify err)
    .done()


  it 'should publish and unplublish products', (done) ->
    csv =
      """
      productType,name.en,slug.en,variantId,sku,myStateAttrib
      #{@productType.name},myProduct1,my-slug1,1,sku1,foo
      #{@productType.name},myProduct2,my-slug2,1,sku2,bar
      """
    @importer.import(csv)
    .then (result) =>
      expect(_.size result).toBe 2
      expect(result[0]).toBe '[row 2] New product created.'
      expect(result[1]).toBe '[row 3] New product created.'
      @importer.changeState(true, false, performAllProducts)
    .then (result) =>
      expect(_.size result).toBe 2
      expect(result[0]).toBe '[row 0] Product published.'
      expect(result[1]).toBe '[row 0] Product published.'
      @importer.changeState(false, false, performAllProducts)
    .then (result) ->
      expect(_.size result).toBe 2
      expect(result[0]).toBe '[row 0] Product unpublished.'
      expect(result[1]).toBe '[row 0] Product unpublished.'
      done()
    .fail (err) ->
      done(_.prettify err)
    .done()

  it 'should only published products with hasStagedChanges', (done) ->
    csv =
      """
      productType,name.en,slug.en,variantId,sku,myStateAttrib
      #{@productType.name},myProduct1,my-slug1,1,sku1,foo
      #{@productType.name},myProduct2,my-slug2,1,sku2,bar
      """
    @importer.import(csv)
    .then (result) =>
      expect(_.size result).toBe 2
      expect(result[0]).toBe '[row 2] New product created.'
      expect(result[1]).toBe '[row 3] New product created.'
      @importer.changeState(true, false, performAllProducts)
    .then (result) =>
      expect(_.size result).toBe 2
      expect(result[0]).toBe '[row 0] Product published.'
      expect(result[1]).toBe '[row 0] Product published.'
      csv =
        """
        productType,name.en,slug.en,variantId,sku,myStateAttrib
        #{@productType.name},myProduct1,my-slug1,1,sku1,foo
        #{@productType.name},myProduct2,my-slug2,1,sku2,baz
        """
      im = new Import Config
      im.import(csv)
    .then (result) =>
      expect(_.size result).toBe 2
      expect(result[0]).toBe '[row 2] Product update not necessary.'
      expect(result[1]).toBe '[row 3] Product updated.'
      @importer.changeState(true, false, performAllProducts)
    .then (result) ->
      expect(_.size result).toBe 2
      expect(_.contains(result, '[row 0] Product published.')).toBe true
      expect(_.contains(result, '[row 0] Product is already published - no staged changes.')).toBe true
      done()
    .fail (err) ->
      done(_.prettify err)
    .done()

  it 'should delete unplublished products', (done) ->
    csv =
      """
      productType,name.en,slug.en,variantId,sku,myStateAttrib
      #{@productType.name},myProduct1,my-slug1,1,sku1,foo
      #{@productType.name},myProduct2,my-slug2,1,sku2,bar
      """
    @importer.import(csv)
    .then (result) =>
      expect(_.size result).toBe 2
      expect(result[0]).toBe '[row 2] New product created.'
      expect(result[1]).toBe '[row 3] New product created.'
      @importer.changeState(true, true, performAllProducts)
    .then (result) ->
      expect(_.size result).toBe 2
      expect(result[0]).toBe '[row 0] Product deleted.'
      expect(result[1]).toBe '[row 0] Product deleted.'
      done()
    .fail (err) ->
      done(_.prettify err)
    .done()
