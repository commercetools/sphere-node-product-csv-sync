Promise = require 'bluebird'
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

createImporter = ->
  im = new Import Config
  im.matchBy = 'sku'
  im.allowRemovalOfVariants = true
  im.suppressMissingHeaderWarning = true
  im

CHANNEL_KEY = 'retailerA'

describe 'Import and publish test', ->

  beforeEach (done) ->
    jasmine.getEnv().defaultTimeoutInterval = 90000 # 90 sec
    @importer = createImporter()
    @client = @importer.client

    @productType = TestHelpers.mockProductType()

    TestHelpers.setupProductType(@client, @productType)
    .then (result) =>
      @productType = result
      @client.channels.ensure(CHANNEL_KEY, 'InventorySupply')
    .then -> done()
    .catch (err) -> done _.prettify(err.body)
    .done()
  , 120000 # 2min

  describe '#import', ->

    beforeEach ->
      @newProductName = TestHelpers.uniqueId 'name-'
      @newProductSlug = TestHelpers.uniqueId 'slug-'
      @newProductSku = TestHelpers.uniqueId 'sku-'
      @newProductKey = TestHelpers.uniqueId 'key-'

    it 'should import products and publish them afterward', (done) ->
      csv =
        """
        productType,name,key,variantId,slug,publish
        #{@productType.id},#{@newProductName},#{@newProductKey},1,#{@newProductSlug},true
        #{@productType.id},#{@newProductName}1,#{@newProductKey+1},1,#{@newProductSlug}1,false
        """

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] New product created.',
          '[row 3] New product created.'
        ]
        @client.productProjections.staged(true).where("productType(id=\"#{@productType.id}\")").fetch()
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
      .catch (err) -> done _.prettify(err)


    it 'should update products and publish them afterward', (done) ->
      csv =
        """
        productType,key,variantId,sku,name,publish
        #{@productType.id},#{@newProductKey},1,#{@newProductSku},#{@newProductName},true
        #{@productType.id},#{@newProductKey+1},1,#{@newProductSku}1,#{@newProductName}1,true
        """

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2

        csv =
          """
          productType,variantId,sku,name,key,publish
          #{@productType.id},1,#{@newProductSku},#{@newProductName}2,#{@newProductKey+2},true
          #{@productType.id},1,#{@newProductSku}1,#{@newProductName}12,#{@newProductKey+3},
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] Product updated.',
          '[row 3] Product updated.'
        ]
        @client.productProjections.staged(true).where("productType(id=\"#{@productType.id}\")").fetch()
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
      .catch (err) -> done _.prettify(err)

    it 'should update and publish product when matching using SKU', (done) ->
      csv =
        """
        productType,variantId,name,key,sku,publish
        #{@productType.id},1,#{@newProductName}1,#{@newProductKey+1},#{@newProductSku}1,true
        ,2,,,#{@newProductSku}2,false
        #{@productType.id},1,#{@newProductName}3,#{@newProductKey+23},#{@newProductSku}3,true
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
          productType,key,sku,prices,publish
          #{@productType.id},#{@newProductKey+1},#{@newProductSku}1,EUR 111,true
          #{@productType.id},#{@newProductKey+1},#{@newProductSku}2,EUR 222,false
          #{@productType.id},#{@newProductKey+23},#{@newProductSku}3,EUR 333,false
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] Product updated.',
          '[row 4] Product updated.'
        ]
        @client.productProjections.staged(true).where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) =>
        products = _.where(result.body.results, { published: true })
        expect(_.size products).toBe 2

        p = _.where(products, { hasStagedChanges: false })
        expect(p.length).toBe 1
        expect(p[0].variants.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}1"
        expect(p[0].masterVariant.prices[0].value).toEqual
          currencyCode: 'EUR',
          centAmount: 111
        expect(p[0].variants[0].prices[0].value).toEqual
          currencyCode: 'EUR',
          centAmount: 222

        p = _.where(products, { hasStagedChanges: true })
        expect(p.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}3"
        expect(p[0].masterVariant.prices[0].value).toEqual
          currencyCode: 'EUR',
          centAmount: 333

        done()
      .catch (err) -> done _.prettify(err)

    it 'should publish even if there are no update actions', (done) ->
      csv =
        """
        productType,variantId,name,key,sku
        #{@productType.id},1,#{@newProductName}1,#{@newProductKey+1},#{@newProductSku}1
        ,2,,,#{@newProductSku}2
        #{@productType.id},1,#{@newProductName}3,#{@newProductKey+23},#{@newProductSku}3
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
          productType,key,sku,publish
          #{@productType.id},#{@newProductKey+1},#{@newProductSku}1,true
          #{@productType.id},#{@newProductKey+23},#{@newProductSku}3,false
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 2
        expect(result).toEqual [
          '[row 2] Product updated.',
          '[row 3] Product update not necessary.'
        ]

        @client.productProjections.staged(true).where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) =>
        p = _.where(result.body.results, { published: true })
        expect(p.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}1"

        p = _.where(result.body.results, { published: false })
        expect(p.length).toBe 1
        expect(p[0].name).toEqual en: "#{@newProductName}3"

        done()
      .catch (err) -> done _.prettify(err)

