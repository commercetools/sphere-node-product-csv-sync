Promise = require 'bluebird'
fetch = require 'node-fetch'
_ = require 'underscore'
archiver = require 'archiver'
_.mixin require('underscore-mixins')
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
  fetch: fetch
}
httpConfig = { host: 'https://api.sphere.io', fetch: fetch }
userAgentConfig = {}

createImporter = (format) ->
  config = JSON.parse(JSON.stringify(Config)) # cloneDeep
  config.importFormat = format || "csv"
  im = new Import {
    authConfig: authConfig
    httpConfig: httpConfig
    userAgentConfig: userAgentConfig
  }
  im.matchBy = 'sku'
  im.allowRemovalOfVariants = true
  im.suppressMissingHeaderWarning = true
  im

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

describe 'Import integration test', ->

  beforeEach (done) ->
    jasmine.DEFAULT_TIMEOUT_INTERVAL = 120000 # 2mins
    @importer = createImporter()
    @importer.suppressMissingHeaderWarning = true
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
    .catch (err) -> done.fail _.prettify(err.body)
  , 120000 # 2min

  describe '#import', ->

    beforeEach ->
      @newProductName = TestHelpers.uniqueId 'name-'
      @newProductSlug = TestHelpers.uniqueId 'slug-'
      @newProductSku = TestHelpers.uniqueId 'sku-'

    it 'should import multiple archived products from CSV', (done) ->
      tempDir = tmp.dirSync({ unsafeCleanup: true })
      archivePath = path.join tempDir.name, 'products.zip'

      csv = [
        """
          productType,name,variantId,slug
          #{@productType.id},#{@newProductName},1,#{@newProductSlug}
          """,
        """
          productType,name,variantId,slug
          #{@productType.id},#{@newProductName+1},1,#{@newProductSlug+1}
          """
      ]

      Promise.map csv, (content, index) ->
        fs.writeFileAsync path.join(tempDir.name, "products-#{index}.csv"), content
      .then ->
        archive = archiver 'zip'
        outputStream = fs.createWriteStream archivePath

        new Promise (resolve, reject) ->
          outputStream.on 'close', () -> resolve()
          archive.on 'error', (err) -> reject(err)
          archive.pipe outputStream
          archive.glob('**', { cwd: tempDir.name })
          archive.finalize()
      .then =>
        @importer.importManager(archivePath, true)
      .then =>
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .sort("createdAt", "ASC")
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 2

        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug

        p = result.body.results[1]
        expect(p.name).toEqual en: @newProductName+1
        expect(p.slug).toEqual en: @newProductSlug+1

        done()
      .catch (err) -> done.fail _.prettify(err)
      .finally ->
        tempDir.removeCallback()

    # TODO: Test broken; fixme!
    xit 'should import multiple archived products from XLSX', (done) ->
      importer = createImporter("xlsx")
      tempDir = tmp.dirSync({ unsafeCleanup: true })
      archivePath = path.join tempDir.name, 'products.zip'

      data = [
        [
          ["productType","name","variantId","slug"],
          [@productType.id,@newProductName,1,@newProductSlug]
        ],
        [
          ["productType","name","variantId","slug"],
          [@productType.id,@newProductName+1,1,@newProductSlug+1]
        ]
      ]

      Promise.map data, (content, index) ->
        writeXlsx(path.join(tempDir.name, "products-#{index}.xlsx"), content)
      .then ->
        archive = archiver 'zip'
        outputStream = fs.createWriteStream archivePath

        new Promise (resolve, reject) ->
          outputStream.on 'close', () -> resolve()
          archive.on 'error', (err) -> reject(err)
          archive.pipe outputStream
          archive.glob('**', { cwd: tempDir.name })
          archive.finalize()
      .then =>
        importer.importManager(archivePath, true)
      .then =>
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .sort("createdAt", "ASC")
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 2

        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug

        p = result.body.results[1]
        expect(p.name).toEqual en: @newProductName+1
        expect(p.slug).toEqual en: @newProductSlug+1

        done()
      .catch (err) -> done.fail _.prettify(err)
      .finally ->
        tempDir.removeCallback()
