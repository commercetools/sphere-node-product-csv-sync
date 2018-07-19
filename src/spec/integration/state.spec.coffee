_ = require 'underscore'
_.mixin require('underscore-mixins')
{Import} = require '../../lib/main'
Config = require '../../config'
TestHelpers = require './testhelpers'

performAllProducts = -> true

TEXT_ATTRIBUTE_NONE = 'attr-text-n'

describe 'State integration tests', ->
  { client_id, client_secret, project_key } = Config.config
  authConfig = {
    host: 'https://auth.sphere.io'
    projectKey: project_key
    credentials: {
      clientId: client_id
      clientSecret: client_secret
    }
  }
  httpConfig = { host: 'https://api.sphere.io' }
  userAgentConfig = {}
  beforeEach (done) ->
    @importer = new Import {
      authConfig: authConfig
      httpConfig: httpConfig
      userAgentConfig: userAgentConfig
    }
    @importer.matchBy = 'sku'
    @importer.suppressMissingHeaderWarning = true
    @client = @importer.client

    @productType = TestHelpers.mockProductType()

    TestHelpers.setupProductType(@client, @productType, null, project_key)
    .then (result) =>
      @productType = result
      done()
    .catch (err) -> done _.prettify(err.body)
  , 50000 # 50sec


  it 'should publish and unpublish products', (done) ->
    csv =
      """
      productType,name.en,slug.en,variantId,sku,#{TEXT_ATTRIBUTE_NONE}
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
    .catch (err) -> done _.prettify(err)
  , 50000 # 50sec

  it 'should only published products with hasStagedChanges', (done) ->
    csv =
      """
      productType,name.en,slug.en,variantId,sku,#{TEXT_ATTRIBUTE_NONE}
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
        productType,name.en,slug.en,variantId,sku,#{TEXT_ATTRIBUTE_NONE}
        #{@productType.name},myProduct1,my-slug1,1,sku1,foo
        #{@productType.name},myProduct2,my-slug2,1,sku2,baz
        """
      im = new Import {
        authConfig: authConfig
        httpConfig: httpConfig
        userAgentConfig: userAgentConfig
      }
      im.matchBy = 'slug'
      im.suppressMissingHeaderWarning = true
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
    .catch (err) -> done _.prettify(err)
  , 50000 # 50sec

  it 'should delete unpublished products', (done) ->
    csv =
      """
      productType,name.en,slug.en,variantId,sku,#{TEXT_ATTRIBUTE_NONE}
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
    .catch (err) -> done _.prettify(err)
  , 50000 # 50sec
