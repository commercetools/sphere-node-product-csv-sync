Promise = require 'bluebird'
_ = require 'underscore'
archiver = require 'archiver'
_.mixin require('underscore-mixins')
iconv = require 'iconv-lite'
{Import} = require '../../lib/main'
Config = require '../../config'
TestHelpers = require './testhelpers'
Excel = require 'exceljs'
cuid = require 'cuid'
path = require 'path'
tmp = require 'tmp'
fs = Promise.promisifyAll require('fs')
# will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup()
CHANNEL_KEY = 'retailerA'

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

writeXlsx = (filePath, data) ->
  workbook = new Excel.Workbook()
  workbook.created = new Date()
  worksheet = workbook.addWorksheet('Products')
  console.log "Generating Xlsx file"

  data.forEach (items, index) ->
    if index
      worksheet.addRow items
    else
      headers = []
      for i of items
        headers.push {
          header: items[i]
        }
      worksheet.columns = headers

  workbook.xlsx.writeFile(filePath)

createImporter = ->
  Config.importFormat = "xlsx"
  im = new Import {
    authConfig: authConfig
    httpConfig: httpConfig
    userAgentConfig: userAgentConfig
  }
  im.matchBy = 'sku'
  im.allowRemovalOfVariants = true
  im.suppressMissingHeaderWarning = true
  im

describe 'Import integration test', ->

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

  describe '#importXlsx', ->

    beforeEach ->
      @newProductName = TestHelpers.uniqueId 'name-'
      @newProductSlug = TestHelpers.uniqueId 'slug-'
      @newProductSku = TestHelpers.uniqueId 'sku-'

    it 'should import a simple product from xlsx', (done) ->
      filePath = "/tmp/test-import.xlsx"
      data = [
        ["productType","name","variantId","slug"],
        [@productType.id,@newProductName,1,@newProductSlug]
      ]

      writeXlsx(filePath, data)
      .then () =>
        @importer.importManager(filePath)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged(true)
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug
        done()
      .catch (err) -> done _.prettify(err)

    it 'should import a product with prices (even when one of them is discounted)', (done) ->
      filePath = "/tmp/test-import.xlsx"
      data = [
        ["productType","name","variantId","slug","prices"],
        [@productType.id,@newProductName,1,@newProductSlug,"EUR 899;CH-EUR 999;DE-EUR 999|799;CH-USD 77777700 ##{CHANNEL_KEY}"]
      ]

      writeXlsx(filePath, data)
      .then () =>
        @importer.importManager(filePath)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged(true)
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(_.size p.masterVariant.prices).toBe 4
        prices = p.masterVariant.prices
        expect(prices[0].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 899)
        expect(prices[1].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 999)
        expect(prices[1].country).toBe 'CH'
        expect(prices[2].country).toBe 'DE'
        expect(prices[2].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 999)
        expect(prices[3].channel.typeId).toBe 'channel'
        expect(prices[3].channel.id).toBeDefined()
        done()
      .catch (err) -> done _.prettify(err)

    it 'should do nothing on 2nd import run', (done) ->
      filePath = "/tmp/test-import.xlsx"
      data = [
        ["productType","name","variantId","slug"],
        [@productType.id,@newProductName,1,@newProductSlug]
      ]

      writeXlsx(filePath, data)
      .then () =>
        @importer.importManager(filePath)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        im = createImporter()
        im.matchBy = 'slug'
        im.importManager(filePath)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        done()
      .catch (err) -> done _.prettify(err)


    it 'should do a partial update of prices based on SKUs', (done) ->
      filePath = "/tmp/test-import.xlsx"
      data = [
        ["productType","name","sku","variantId","prices"],
        [@productType.id,@newProductName,@newProductSku+1,1,"EUR 999"],
        [null,null,@newProductSku+2,2,"USD 70000"]
      ]

      writeXlsx(filePath, data)
      .then () =>
        @importer.importManager(filePath)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
        """
          sku,prices,productType
          #{@newProductSku+1},EUR 1999,#{@productType.name}
          #{@newProductSku+2},USD 80000,#{@productType.name}
          """
        im = createImporter()
        im.allowRemovalOfVariants = false
        im.updatesOnly = true
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged(true)
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual {en: @newProductName}
        expect(p.masterVariant.sku).toBe "#{@newProductSku}1"
        expect(p.masterVariant.prices[0].value).toEqual jasmine.objectContaining(centAmount: 1999, currencyCode: 'EUR')
        expect(p.variants[0].sku).toBe "#{@newProductSku}2"
        expect(p.variants[0].prices[0].value).toEqual jasmine.objectContaining(centAmount: 80000, currencyCode: 'USD')
        done()
      .catch (err) -> done _.prettify(err)
