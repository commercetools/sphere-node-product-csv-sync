Promise = require 'bluebird'
fetch = require 'node-fetch'
_ = require 'underscore'
_.mixin require('underscore-mixins')
{Import} = require '../../lib/main'
Config = require '../../config'
TestHelpers = require './testhelpers'
cuid = require 'cuid'
path = require 'path'
tmp = require 'tmp'
fs = Promise.promisifyAll require('fs')
# will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup()

{ client_id, client_secret, project_key } = Config.config
authConfig = {
  host: 'https://auth.sphere.io'
  projectKey: project_key
  credentials: {
    clientId: client_id
    clientSecret: client_secret
  }
  fetch: fetch
}
httpConfig = { host: 'https://api.sphere.io', fetch: fetch }
userAgentConfig = {}

createImporter = ->
  im = new Import {
    authConfig: authConfig
    httpConfig: httpConfig
    userAgentConfig: userAgentConfig
  }
  im.matchBy = 'sku'
  im.allowRemovalOfVariants = true
  im.suppressMissingHeaderWarning = true
  im

CHANNEL_KEY = 'retailerA'

describe 'Import and publish test', ->

  beforeEach (done) ->
    jasmine.DEFAULT_TIMEOUT_INTERVAL = 90000 # 90 sec
    @importer = createImporter()
    @client = @importer.client

    @productType = TestHelpers.mockProductType()

    TestHelpers.setupProductType(@client, @productType, null, project_key)
    .then (result) =>
      @productType = result
      # Check if channel exists
      service = TestHelpers.createService(project_key, 'channels')
      request = {
        uri: service
          .where("key=\"#{CHANNEL_KEY}\"")
          .build()
        method: 'GET'
      }
      @client.execute request
    .then (result) =>
      # Create the channel if it doesn't exist else ignore
      if (!result.body.total)
        service = TestHelpers.createService(project_key, 'channels')
        request = {
          uri: service.build()
          method: 'POST'
          body:
            key: CHANNEL_KEY
            roles: ['InventorySupply']
        }
        @client.execute request
    .then -> done()
    .catch (err) -> done _.prettify(err.body)
  , 120000 # 2min

  describe '#import', ->

    beforeEach ->
      @newProductName = TestHelpers.uniqueId 'name-'
      @newProductSlug = TestHelpers.uniqueId 'slug-'
      @newProductSku = TestHelpers.uniqueId 'sku-'

    it 'should import products and publish them afterward', (done) ->
      csv =
        """
        productType,name,variantId,slug,publish
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},true
        #{@productType.id},#{@newProductName}1,1,#{@newProductSlug}1,false
        """

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] New product created.',
          '[row 3] New product created.'
        ]
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 2
        products = result.body.results
        p = _.where(products, { published: true})
        expect(p.length).toBe 1
        expect(p[0].slug).toEqual en: @newProductSlug

        p = _.where(products, { published: false})
        expect(p.length).toBe 1
        expect(p[0].slug).toEqual en: "#{@newProductSlug}1"
        done()
      .catch (err) -> done.fail _.prettify(err)


    it 'should update products and publish them afterward', (done) ->
      csv =
        """
        productType,variantId,sku,name,publish
        #{@productType.id},1,#{@newProductSku},#{@newProductName},true
        #{@productType.id},1,#{@newProductSku}1,#{@newProductName}1,true
        """

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2

        csv =
          """
          productType,variantId,sku,name,publish
          #{@productType.id},1,#{@newProductSku},#{@newProductName}2,true
          #{@productType.id},1,#{@newProductSku}1,#{@newProductName}12,
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] Product updated.',
          '[row 3] Product updated.'
        ]
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        products = _.where(result.body.results, { published: true })
        expect(_.size products).toBe 2

        p = _.where(products, { hasStagedChanges: false })
        expect(p.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}2"

        p = _.where(products, { hasStagedChanges: true })
        expect(p.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}12"
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should update and publish product when matching using SKU', (done) ->
      csv =
        """
        productType,variantId,name,sku,publish
        #{@productType.id},1,#{@newProductName}1,#{@newProductSku}1,true
        ,2,,#{@newProductSku}2,false
        #{@productType.id},1,#{@newProductName}3,#{@newProductSku}3,true
        """

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] New product created.',
          '[row 4] New product created.'
        ]

        csv =
          """
          productType,sku,prices,publish
          #{@productType.id},#{@newProductSku}1,EUR 111,true
          #{@productType.id},#{@newProductSku}2,EUR 222,false
          #{@productType.id},#{@newProductSku}3,EUR 333,false
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] Product updated.',
          '[row 4] Product updated.'
        ]
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        products = _.where(result.body.results, { published: true })
        expect(_.size products).toBe 2

        p = _.where(products, { hasStagedChanges: false })
        expect(p.length).toBe 1
        expect(p[0].variants.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}1"
        expect(p[0].masterVariant.prices[0].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 111)
        expect(p[0].variants[0].prices[0].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 222)

        p = _.where(products, { hasStagedChanges: true })
        expect(p.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}3"
        expect(p[0].masterVariant.prices[0].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 333)

        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should publish even if there are no update actions', (done) ->
      csv =
        """
        productType,variantId,name,sku
        #{@productType.id},1,#{@newProductName}1,#{@newProductSku}1
        ,2,,#{@newProductSku}2
        #{@productType.id},1,#{@newProductName}3,#{@newProductSku}3
        """

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] New product created.',
          '[row 4] New product created.'
        ]

        csv =
          """
          productType,sku,publish
          #{@productType.id},#{@newProductSku}1,true
          #{@productType.id},#{@newProductSku}3,false
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] Product updated.',
          '[row 3] Product update not necessary.'
        ]

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        p = _.where(result.body.results, { published: true })
        expect(p.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}1"

        p = _.where(result.body.results, { published: false })
        expect(p.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}3"

        done()
      .catch (err) -> done.fail _.prettify(err)

