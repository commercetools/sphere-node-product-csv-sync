_ = require 'underscore'
path = require 'path'
sinon = require 'sinon'
iconv = require 'iconv-lite'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')
Config = require '../../config'
TestHelpers = require './testhelpers'
{ Export } = require '../../lib/main'
{ createRequestBuilder } = require '@commercetools/api-request-builder'
extract = require 'extract-zip'
extractArchive = Promise.promisify(extract)
tmp = require 'tmp'
# will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup()

SpecReporter = require('jasmine-spec-reporter').SpecReporter
jasmine.getEnv().clearReporters()
jasmine.getEnv().addReporter(new SpecReporter({
  spec: {
    displayPending: true
  }
}))

process.on('unhandledRejection', (error) ->
  console.error('unhandledRejection', error)
)

describe 'Export integration tests', ->
  { client_id, client_secret, project_key } = Config.config
  constructorOptions = {
    authConfig: {
      host: 'https://auth.sphere.io'
      projectKey: project_key
      credentials: {
        clientId: client_id
        clientSecret: client_secret
      }
    }
    httpConfig: { host: 'https://api.sphere.io' }
    userAgentConfig: {}
  }
  beforeEach (done) ->
    jasmine.DEFAULT_TIMEOUT_INTERVAL = 50000 # 50 sec
    @export = new Export(constructorOptions)
    @client = @export.client
    @productType = TestHelpers.mockProductType()

    @product =
      key: 'productKey'
      productType:
        typeId: 'product-type'
        id: 'TODO'
      name:
        en: 'Foo'
      slug:
        en: 'foo'
      variants: [
        key: 'variantKey'
        sku: '123'
        attributes: [
          {
            name: "attr-lenum-n"
            value: {
              key: "lenum1"
              label: {
                en: "Enum1"
              }
            }
          }
          name: "attr-set-lenum-n"
          value: [
            {
              key: "lenum1"
              label: {
                en: "Enum1"
              }
            },
            {
              key: "lenum2"
              label: {
                en: "Enum2"
              }
            }
          ]
        ]
      ]
    TestHelpers.setupProductType(@client, @productType, @product, project_key)
    .then -> done()
    .catch (err) -> done _.prettify(err.body)
  , 60000 # 60sec

  it 'should inform about a bad header in the template', (done) ->
    template =
      '''
      productType,name,name
      '''
    @export.exportDefault(template, null)
    .then ->
      done('Export should fail!')
    .catch (err) ->
      expect(_.size err).toBe 2
      expect(err[0]).toBe 'There are duplicate header entries!'
      expect(err[1]).toBe "You need either the column 'variantId' or 'sku' to identify your variants!"
      done()

  it 'should inform that there are no products', (done) ->
    template =
      '''
      productType,name,variantId
      '''
    outputLocation = '/tmp/output.csv'
    expectedCSV =
      """
      productType,name,variantId

      """
    @export.exportDefault(template, outputLocation, false)
    .then (result) ->
      expect(result).toBe 'Export done.'
      fs.readFileAsync outputLocation, {encoding: 'utf8'}
    .then (content) ->
      expect(content).toBe expectedCSV
      done()
    .catch (err) -> done _.prettify(err)

  it 'should export based on minimum template', (done) ->
    template =
      '''
      productType,name,variantId
      '''
    outputLocation = '/tmp/output.csv'
    expectedCSV =
      """
      productType,name,variantId
      #{@productType.name},,1
      ,,2

      """
    @export.exportDefault(template, outputLocation)
    .then (result) ->
      expect(result).toBe 'Export done.'
      fs.readFileAsync outputLocation, {encoding: 'utf8'}
    .then (content) ->
      expect(content).toBe expectedCSV
      done()
    .catch (err) -> done _.prettify(err)

  it 'should export labels of lenum and set of lenum', (done) ->
    template =
    '''
      productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en
      '''
    outputLocation = '/tmp/output.csv'
    expectedCSV =
    """
      productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en
      #{@productType.name},,1
      ,,2,Enum1,Enum1;Enum2

      """
    @export.exportDefault(template, outputLocation)
    .then (result) ->
      expect(result).toBe 'Export done.'
      fs.readFileAsync outputLocation, {encoding: 'utf8'}
    .then (content) ->
      expect(content).toBe expectedCSV
      done()
    .catch (err) -> done _.prettify(err)


  it 'should do a full export', (done) ->
    tempDir = tmp.dirSync({ unsafeCleanup: true })
    outputLocation = path.join tempDir.name, 'output.zip'
    expectedHeader = '_published,_hasStagedChanges,productType,variantId,variantKey,id,key,sku,prices,tax,categories,images,name.en,description.en,slug.en,metaTitle.en,metaDescription.en,metaKeywords.en,searchKeywords.en,attr-text-n,attr-ltext-n.en,attr-enum-n,attr-lenum-n,attr-number-n,attr-boolean-n,attr-money-n,attr-date-n,attr-time-n,attr-datetime-n,attr-ref-product-n,attr-ref-product-type-n,attr-ref-channel-n,attr-ref-state-n,attr-ref-zone-n,attr-ref-shipping-method-n,attr-ref-category-n,attr-ref-review-n,attr-ref-key-value-n,attr-set-text-n,attr-set-ltext-n.en,attr-set-enum-n,attr-set-lenum-n,attr-set-number-n,attr-set-boolean-n,attr-set-money-n,attr-set-date-n,attr-set-time-n,attr-set-datetime-n,attr-set-ref-product-n,attr-set-ref-product-type-n,attr-set-ref-channel-n,attr-set-ref-state-n,attr-set-ref-zone-n,attr-set-ref-shipping-method-n,attr-set-ref-category-n,attr-set-ref-review-n,attr-set-ref-key-value-n,attr-text-u,attr-ltext-u.en,attr-enum-u,attr-lenum-u,attr-number-u,attr-boolean-u,attr-money-u,attr-date-u,attr-time-u,attr-datetime-u,attr-ref-product-u,attr-ref-product-type-u,attr-ref-channel-u,attr-ref-state-u,attr-ref-zone-u,attr-ref-shipping-method-u,attr-ref-category-u,attr-ref-review-u,attr-ref-key-value-u,attr-set-text-u,attr-set-ltext-u.en,attr-set-enum-u,attr-set-lenum-u,attr-set-number-u,attr-set-boolean-u,attr-set-money-u,attr-set-date-u,attr-set-time-u,attr-set-datetime-u,attr-set-ref-product-u,attr-set-ref-product-type-u,attr-set-ref-channel-u,attr-set-ref-state-u,attr-set-ref-zone-u,attr-set-ref-shipping-method-u,attr-set-ref-category-u,attr-set-ref-review-u,attr-set-ref-key-value-u,attr-text-cu,attr-ltext-cu.en,attr-enum-cu,attr-lenum-cu,attr-number-cu,attr-boolean-cu,attr-money-cu,attr-date-cu,attr-time-cu,attr-datetime-cu,attr-ref-product-cu,attr-ref-product-type-cu,attr-ref-channel-cu,attr-ref-state-cu,attr-ref-zone-cu,attr-ref-shipping-method-cu,attr-ref-category-cu,attr-ref-review-cu,attr-ref-key-value-cu,attr-set-text-cu,attr-set-ltext-cu.en,attr-set-enum-cu,attr-set-lenum-cu,attr-set-number-cu,attr-set-boolean-cu,attr-set-money-cu,attr-set-date-cu,attr-set-time-cu,attr-set-datetime-cu,attr-set-ref-product-cu,attr-set-ref-product-type-cu,attr-set-ref-channel-cu,attr-set-ref-state-cu,attr-set-ref-zone-cu,attr-set-ref-shipping-method-cu,attr-set-ref-category-cu,attr-set-ref-review-cu,attr-set-ref-key-value-cu,attr-text-sfa,attr-ltext-sfa.en,attr-enum-sfa,attr-lenum-sfa,attr-number-sfa,attr-boolean-sfa,attr-money-sfa,attr-date-sfa,attr-time-sfa,attr-datetime-sfa,attr-ref-product-sfa,attr-ref-product-type-sfa,attr-ref-channel-sfa,attr-ref-state-sfa,attr-ref-zone-sfa,attr-ref-shipping-method-sfa,attr-ref-category-sfa,attr-ref-review-sfa,attr-ref-key-value-sfa,attr-set-text-sfa,attr-set-ltext-sfa.en,attr-set-enum-sfa,attr-set-lenum-sfa,attr-set-number-sfa,attr-set-boolean-sfa,attr-set-money-sfa,attr-set-date-sfa,attr-set-time-sfa,attr-set-datetime-sfa,attr-set-ref-product-sfa,attr-set-ref-product-type-sfa,attr-set-ref-channel-sfa,attr-set-ref-state-sfa,attr-set-ref-zone-sfa,attr-set-ref-shipping-method-sfa,attr-set-ref-category-sfa,attr-set-ref-review-sfa,attr-set-ref-key-value-sfa'
    expectedProduct = 'false,false,ImpEx with all types,1,,MONGO_ID,productKey,,,,,,Foo,,foo,,,,'
    expectedVariant =   ',,,2,variantKey,,,123,,,,,,,,,,,,,,,lenum1,,,,,,,,,,,,,,,,,,,lenum1;lenum2'

    @export.exportFull(outputLocation)
    .then (result) ->
      expect(result).toBe 'Export done.'

      try
        fs.statSync(outputLocation).isFile()
        return Promise.resolve()
      catch err
        return Promise.reject "Archive was not generated"
    .then ->
      console.log "Archive was generated successfully"
      extractArchive(outputLocation, {dir: tempDir.name})
    .then ->

      try
        exportedFolder = path.join tempDir.name, 'products'
        fs.statSync exportedFolder # test if file was created
        files = fs.readdirSync(exportedFolder)
        expect(files.length).toBe 1
        csvFile = path.join exportedFolder, files[0]
        fs.statSync csvFile # test if file was created
      catch e
        return Promise.reject 'Archive was not successfully created or parsed'

      fs.readFileAsync csvFile, {encoding: 'utf8'}
    .then (content) =>
      csv = content.split("\n")
      expect(csv.length).toBe 4

      expect(csv[0]).toBe expectedHeader
      expect(csv[2]).toBe expectedVariant
      expect(csv[3]).toBe ""
      service = TestHelpers.createService(project_key, 'productProjections')
      request = {
        uri: service
          .staged(true)
          .build()
        method: 'GET'
      }
      @client.execute request
      .then (res) ->
        expect(res.body.results.length).toBe 1
        product = res.body.results[0]

        # replace mongoId
        expectedProductLine = expectedProduct.replace('MONGO_ID', product.id)
        expect(csv[1]).toBe expectedProductLine
    .then ->
      done()
    .catch (err) -> done _.prettify(err)
    .finally ->
      tempDir.removeCallback()

  it 'should export data in different encoding', (done) ->
    encoding = 'win1250'
    template =
    '''
      productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en,žškřďťň
      '''
    outputLocation = '/tmp/output.csv'
    expectedCSV =
    """
      productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en,žškřďťň
      #{@productType.name},,1
      ,,2,Enum1,Enum1;Enum2

      """

    # export data in win1250 encoding
    @export.options.encoding = encoding
    @export.exportDefault(template, outputLocation)
    .then (result) ->
      expect(result).toBe 'Export done.'

      fs.readFileAsync outputLocation, {encoding: 'utf8'}
    .then (content) ->
      # compare exported data with text encoded in utf8
      expect(content).not.toBe expectedCSV

      # decode from win1250 to utf8 and compare with expected result
      decoded = iconv.decode(fs.readFileSync(outputLocation), encoding)
      expect(decoded).toBe expectedCSV

      done()
    .catch (err) -> done _.prettify(err)

  it 'should export product with money set attribute', (done) ->
    testProductType = require '../../data/moneySetAttributeProductType'
    testProduct = require '../../data/moneySetAttributeProduct'
    outputLocation = '/tmp/output.csv'
    template =
    '''
      productType,name,variantId,money_attribute,prices
      '''
    expectedCSV =
    """
      productType,name,variantId,money_attribute,prices
      #{testProductType.name},,1,EUR 123456;GBP 98765,DE-EUR 12900$2001-09-11T14:00:00.000Z~2015-09-11T14:00:00.000Z

      """

    TestHelpers.setupProductType(@client, testProductType, testProduct, project_key)
    .then =>
      @export.exportDefault(template, outputLocation)
    .then (result) ->
      expect(result).toBe 'Export done.'
      fs.readFileAsync outputLocation, {encoding: 'utf8'}
    .then (content) =>
      expect(content).toBe expectedCSV
      done()
    .catch (err) -> done _.prettify(err)


  it 'should do a full export with queryString', (done) ->
    exporter = new Export(Object.assign({}, constructorOptions, { export: {
      queryString: 'where=name(en = "Foo")&staged=true'
      isQueryEncoded: false
    } }))
    tempDir = tmp.dirSync({ unsafeCleanup: true })
    outputLocation = path.join tempDir.name, 'output-querystring.zip'
    expectedHeader = '_published,_hasStagedChanges,productType,variantId,variantKey,id,key,sku,prices,tax,categories,images,name.en,description.en,slug.en,metaTitle.en,metaDescription.en,metaKeywords.en,searchKeywords.en,attr-text-n,attr-ltext-n.en,attr-enum-n,attr-lenum-n,attr-number-n,attr-boolean-n,attr-money-n,attr-date-n,attr-time-n,attr-datetime-n,attr-ref-product-n,attr-ref-product-type-n,attr-ref-channel-n,attr-ref-state-n,attr-ref-zone-n,attr-ref-shipping-method-n,attr-ref-category-n,attr-ref-review-n,attr-ref-key-value-n,attr-set-text-n,attr-set-ltext-n.en,attr-set-enum-n,attr-set-lenum-n,attr-set-number-n,attr-set-boolean-n,attr-set-money-n,attr-set-date-n,attr-set-time-n,attr-set-datetime-n,attr-set-ref-product-n,attr-set-ref-product-type-n,attr-set-ref-channel-n,attr-set-ref-state-n,attr-set-ref-zone-n,attr-set-ref-shipping-method-n,attr-set-ref-category-n,attr-set-ref-review-n,attr-set-ref-key-value-n,attr-text-u,attr-ltext-u.en,attr-enum-u,attr-lenum-u,attr-number-u,attr-boolean-u,attr-money-u,attr-date-u,attr-time-u,attr-datetime-u,attr-ref-product-u,attr-ref-product-type-u,attr-ref-channel-u,attr-ref-state-u,attr-ref-zone-u,attr-ref-shipping-method-u,attr-ref-category-u,attr-ref-review-u,attr-ref-key-value-u,attr-set-text-u,attr-set-ltext-u.en,attr-set-enum-u,attr-set-lenum-u,attr-set-number-u,attr-set-boolean-u,attr-set-money-u,attr-set-date-u,attr-set-time-u,attr-set-datetime-u,attr-set-ref-product-u,attr-set-ref-product-type-u,attr-set-ref-channel-u,attr-set-ref-state-u,attr-set-ref-zone-u,attr-set-ref-shipping-method-u,attr-set-ref-category-u,attr-set-ref-review-u,attr-set-ref-key-value-u,attr-text-cu,attr-ltext-cu.en,attr-enum-cu,attr-lenum-cu,attr-number-cu,attr-boolean-cu,attr-money-cu,attr-date-cu,attr-time-cu,attr-datetime-cu,attr-ref-product-cu,attr-ref-product-type-cu,attr-ref-channel-cu,attr-ref-state-cu,attr-ref-zone-cu,attr-ref-shipping-method-cu,attr-ref-category-cu,attr-ref-review-cu,attr-ref-key-value-cu,attr-set-text-cu,attr-set-ltext-cu.en,attr-set-enum-cu,attr-set-lenum-cu,attr-set-number-cu,attr-set-boolean-cu,attr-set-money-cu,attr-set-date-cu,attr-set-time-cu,attr-set-datetime-cu,attr-set-ref-product-cu,attr-set-ref-product-type-cu,attr-set-ref-channel-cu,attr-set-ref-state-cu,attr-set-ref-zone-cu,attr-set-ref-shipping-method-cu,attr-set-ref-category-cu,attr-set-ref-review-cu,attr-set-ref-key-value-cu,attr-text-sfa,attr-ltext-sfa.en,attr-enum-sfa,attr-lenum-sfa,attr-number-sfa,attr-boolean-sfa,attr-money-sfa,attr-date-sfa,attr-time-sfa,attr-datetime-sfa,attr-ref-product-sfa,attr-ref-product-type-sfa,attr-ref-channel-sfa,attr-ref-state-sfa,attr-ref-zone-sfa,attr-ref-shipping-method-sfa,attr-ref-category-sfa,attr-ref-review-sfa,attr-ref-key-value-sfa,attr-set-text-sfa,attr-set-ltext-sfa.en,attr-set-enum-sfa,attr-set-lenum-sfa,attr-set-number-sfa,attr-set-boolean-sfa,attr-set-money-sfa,attr-set-date-sfa,attr-set-time-sfa,attr-set-datetime-sfa,attr-set-ref-product-sfa,attr-set-ref-product-type-sfa,attr-set-ref-channel-sfa,attr-set-ref-state-sfa,attr-set-ref-zone-sfa,attr-set-ref-shipping-method-sfa,attr-set-ref-category-sfa,attr-set-ref-review-sfa,attr-set-ref-key-value-sfa'
    expectedProduct = 'false,false,ImpEx with all types,1,,MONGO_ID,productKey,,,,,,Foo,,foo,,,,'
    expectedVariant =   ',,,2,variantKey,,,123,,,,,,,,,,,,,,,lenum1,,,,,,,,,,,,,,,,,,,lenum1;lenum2'

    exporter.exportFull(outputLocation)
      .then (result) ->
        expect(result).toBe 'Export done.'
        try
          fs.statSync(outputLocation).isFile()
          return Promise.resolve()
        catch err
          return Promise.reject "Archive was not generated"
      .then ->
        console.log "Archive was generated successfully"
        extractArchive(outputLocation, {dir: tempDir.name})
      .then ->

        try
          exportedFolder = path.join tempDir.name, 'products'
          fs.statSync exportedFolder # test if file was created
          files = fs.readdirSync(exportedFolder)
          expect(files.length).toBe 1
          csvFile = path.join exportedFolder, files[0]
          fs.statSync csvFile # test if file was created
        catch e
          return Promise.reject 'Archive was not successfully created or parsed'

        fs.readFileAsync csvFile, {encoding: 'utf8'}
      .then (content) =>
        csv = content.split("\n")
        expect(csv.length).toBe 4

        expect(csv[0]).toBe expectedHeader
        expect(csv[2]).toBe expectedVariant
        expect(csv[3]).toBe ""
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .staged(true)
            .build()
          method: 'GET'
        }
        @client.execute request
        .then (res) ->
          expect(res.body.results.length).toBe 1
          product = res.body.results[0]

          # replace mongoId
          expectedProductLine = expectedProduct.replace('MONGO_ID', product.id)
          expect(csv[1]).toBe expectedProductLine
      .then ->
        done()
      .catch (err) -> done _.prettify(err)
      .finally ->
        tempDir.removeCallback()


  it 'should do a full export with encoded queryString', (done) ->
    exporter = new Export(Object.assign({}, constructorOptions, { export: {
      queryString: 'where=name(en%20%3D%20%22Foo%22)&staged=true',
      isQueryEncoded: true
    } }))
    tempDir = tmp.dirSync({ unsafeCleanup: true })
    outputLocation = path.join tempDir.name, 'output-querystring-encoded.zip'
    expectedHeader = '_published,_hasStagedChanges,productType,variantId,variantKey,id,key,sku,prices,tax,categories,images,name.en,description.en,slug.en,metaTitle.en,metaDescription.en,metaKeywords.en,searchKeywords.en,attr-text-n,attr-ltext-n.en,attr-enum-n,attr-lenum-n,attr-number-n,attr-boolean-n,attr-money-n,attr-date-n,attr-time-n,attr-datetime-n,attr-ref-product-n,attr-ref-product-type-n,attr-ref-channel-n,attr-ref-state-n,attr-ref-zone-n,attr-ref-shipping-method-n,attr-ref-category-n,attr-ref-review-n,attr-ref-key-value-n,attr-set-text-n,attr-set-ltext-n.en,attr-set-enum-n,attr-set-lenum-n,attr-set-number-n,attr-set-boolean-n,attr-set-money-n,attr-set-date-n,attr-set-time-n,attr-set-datetime-n,attr-set-ref-product-n,attr-set-ref-product-type-n,attr-set-ref-channel-n,attr-set-ref-state-n,attr-set-ref-zone-n,attr-set-ref-shipping-method-n,attr-set-ref-category-n,attr-set-ref-review-n,attr-set-ref-key-value-n,attr-text-u,attr-ltext-u.en,attr-enum-u,attr-lenum-u,attr-number-u,attr-boolean-u,attr-money-u,attr-date-u,attr-time-u,attr-datetime-u,attr-ref-product-u,attr-ref-product-type-u,attr-ref-channel-u,attr-ref-state-u,attr-ref-zone-u,attr-ref-shipping-method-u,attr-ref-category-u,attr-ref-review-u,attr-ref-key-value-u,attr-set-text-u,attr-set-ltext-u.en,attr-set-enum-u,attr-set-lenum-u,attr-set-number-u,attr-set-boolean-u,attr-set-money-u,attr-set-date-u,attr-set-time-u,attr-set-datetime-u,attr-set-ref-product-u,attr-set-ref-product-type-u,attr-set-ref-channel-u,attr-set-ref-state-u,attr-set-ref-zone-u,attr-set-ref-shipping-method-u,attr-set-ref-category-u,attr-set-ref-review-u,attr-set-ref-key-value-u,attr-text-cu,attr-ltext-cu.en,attr-enum-cu,attr-lenum-cu,attr-number-cu,attr-boolean-cu,attr-money-cu,attr-date-cu,attr-time-cu,attr-datetime-cu,attr-ref-product-cu,attr-ref-product-type-cu,attr-ref-channel-cu,attr-ref-state-cu,attr-ref-zone-cu,attr-ref-shipping-method-cu,attr-ref-category-cu,attr-ref-review-cu,attr-ref-key-value-cu,attr-set-text-cu,attr-set-ltext-cu.en,attr-set-enum-cu,attr-set-lenum-cu,attr-set-number-cu,attr-set-boolean-cu,attr-set-money-cu,attr-set-date-cu,attr-set-time-cu,attr-set-datetime-cu,attr-set-ref-product-cu,attr-set-ref-product-type-cu,attr-set-ref-channel-cu,attr-set-ref-state-cu,attr-set-ref-zone-cu,attr-set-ref-shipping-method-cu,attr-set-ref-category-cu,attr-set-ref-review-cu,attr-set-ref-key-value-cu,attr-text-sfa,attr-ltext-sfa.en,attr-enum-sfa,attr-lenum-sfa,attr-number-sfa,attr-boolean-sfa,attr-money-sfa,attr-date-sfa,attr-time-sfa,attr-datetime-sfa,attr-ref-product-sfa,attr-ref-product-type-sfa,attr-ref-channel-sfa,attr-ref-state-sfa,attr-ref-zone-sfa,attr-ref-shipping-method-sfa,attr-ref-category-sfa,attr-ref-review-sfa,attr-ref-key-value-sfa,attr-set-text-sfa,attr-set-ltext-sfa.en,attr-set-enum-sfa,attr-set-lenum-sfa,attr-set-number-sfa,attr-set-boolean-sfa,attr-set-money-sfa,attr-set-date-sfa,attr-set-time-sfa,attr-set-datetime-sfa,attr-set-ref-product-sfa,attr-set-ref-product-type-sfa,attr-set-ref-channel-sfa,attr-set-ref-state-sfa,attr-set-ref-zone-sfa,attr-set-ref-shipping-method-sfa,attr-set-ref-category-sfa,attr-set-ref-review-sfa,attr-set-ref-key-value-sfa'
    expectedProduct = 'false,false,ImpEx with all types,1,,MONGO_ID,productKey,,,,,,Foo,,foo,,,,'
    expectedVariant =   ',,,2,variantKey,,,123,,,,,,,,,,,,,,,lenum1,,,,,,,,,,,,,,,,,,,lenum1;lenum2'

    exporter.exportFull(outputLocation)
      .then (result) ->
        expect(result).toBe 'Export done.'
        try
          fs.statSync(outputLocation).isFile()
          return Promise.resolve()
        catch err
          return Promise.reject "Archive was not generated"
      .then ->
        console.log "Archive was generated successfully"
        extractArchive(outputLocation, {dir: tempDir.name})
      .then ->

        try
          exportedFolder = path.join tempDir.name, 'products'
          fs.statSync exportedFolder # test if file was created
          files = fs.readdirSync(exportedFolder)
          expect(files.length).toBe 1
          csvFile = path.join exportedFolder, files[0]
          fs.statSync csvFile # test if file was created
        catch e
          return Promise.reject 'Archive was not successfully created or parsed'

        fs.readFileAsync csvFile, {encoding: 'utf8'}
      .then (content) =>
        csv = content.split("\n")
        expect(csv.length).toBe 4

        expect(csv[0]).toBe expectedHeader
        expect(csv[2]).toBe expectedVariant
        expect(csv[3]).toBe ""
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .staged(true)
            .build()
          method: 'GET'
        }
        @client.execute request
        .then (res) ->
          expect(res.body.results.length).toBe 1
          product = res.body.results[0]

          # replace mongoId
          expectedProductLine = expectedProduct.replace('MONGO_ID', product.id)
          expect(csv[1]).toBe expectedProductLine
      .then ->
        done()
      .catch (err) -> done _.prettify(err)
      .finally ->
        tempDir.removeCallback()

  it 'should try to export into unsupported export format', (done) ->
    exporter = new Export(Object.assign({}, constructorOptions, { exportFormat: "unsupported", }))
    template =
    '''
      productType,name,sku
      '''
    exporter.exportDefault(template, null)
    .then () ->
      done('Export should fail!')
    .catch (err) ->
      expect(err.message).toBe 'Unsupported file type: unsupported, alowed formats are xlsx,csv'
      done()

  it 'should throw an error when exporting into unsupported encoding', (done) ->
    template =
    '''
      productType,name,variantId,attr-lenum-n.en,attr-set-lenum-n.en,žškřďťň
      '''
    outputLocation = '/tmp/output.csv'

    @export.options.encoding = 'unsupportedEncoding'
    @export.exportDefault(template, outputLocation)
    .then () ->
      done("Should throw an exception with unsupported encoding")
    .catch (err) =>
      expect(err.message).toBe "Encoding does not exist: unsupportedEncoding"
      @export.options.encoding = 'utf8'
      done()

  it 'should export current state of products', (done) ->
    client =  @export._createClient()
    processSpy = sinon.spy(@export, '_processChunk')

    # change staged vs current version of a product
    uriService = createRequestBuilder({projectKey: @export.projectKey})
      .productProjections
      .staged(true)
      .perPage(100)

    request = {
      uri: uriService.build(),
      method: 'GET'
    }
    client.execute(request)
    .then (products) =>
      products = products.body.results
      expect(products.length).toBe 1

      uriService = createRequestBuilder({projectKey: @export.projectKey})
        .products
        .byId(products[0].id)

      request = {
        version: products[0].version,
        actions: [
          {
            action: 'changeSlug',
            slug: {
              en: 'CURRENT-SLUG'
            }
          },
          {
            action: 'publish'
          },
          {
            action: 'changeSlug',
            slug: {
              en: 'STAGED-SLUG'
            }
          }
        ]
      }

      client.execute({
        uri: uriService.build(),
        method: 'POST',
        body: JSON.stringify(request)
      })
    .then =>
      template =
      '''
        productType,sku,slug.en
        '''
      outputLocation = '/tmp/output.csv'
      @export.exportDefault(template, outputLocation, true) # export staged
    .then () =>
      products = processSpy.lastCall.args[1] # fetched products
      expect(products.length).toBe 1
      expect(products[0].slug.en).toBe 'STAGED-SLUG'

      template =
        '''
        productType,sku,slug.en
        '''
      outputLocation = '/tmp/output.csv'
      @export.exportDefault(template, outputLocation, false) # export current
    .then () ->
      products = processSpy.lastCall.args[1] # fetched products
      expect(products.length).toBe 1
      expect(products[0].slug.en).toBe 'CURRENT-SLUG'

      processSpy.restore()
      done()
    .catch (err) ->

      console.log(err)
      done _.prettify(err)
