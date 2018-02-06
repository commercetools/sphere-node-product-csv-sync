_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')
{Export, Import} = require '../../lib/main'
Config = require '../../config'
TestHelpers = require './testhelpers'

TEXT_ATTRIBUTE_NONE = 'attr-text-n'
LTEXT_ATTRIBUTE_COMBINATION_UNIQUE = 'attr-ltext-cu'
SET_TEXT_ATTRIBUTE_NONE = 'attr-set-text-n'
BOOLEAN_ATTRIBUTE_NONE = 'attr-boolean-n'

describe 'Impex integration tests', ->

  beforeEach (done) ->
    jasmine.getEnv().defaultTimeoutInterval = 90000 # 90 sec
    @importer = new Import Config
    @importer.matchBy = 'slug'
    @importer.suppressMissingHeaderWarning = true
    @exporter = new Export client: Config
    @client = @importer.client

    @productType = TestHelpers.mockProductType()

    TestHelpers.setupProductType(@client, @productType)
    .then (result) =>
      @productType = result
      done()
    .catch (err) -> done _.prettify(err.body)
    .done()
  , 60000 # 60sec

  it 'should import and re-export a simple product', (done) ->
    header = "productType,key,name.en,slug.en,variantId,sku,prices,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{TEXT_ATTRIBUTE_NONE},#{SET_TEXT_ATTRIBUTE_NONE},#{BOOLEAN_ATTRIBUTE_NONE}"
    p1 =
      """
      #{@productType.name},productKey-1,myProduct1,my-slug1,1,sku1,FR-EUR 999;CHF 1099,some Text,foo,false
      ,,,,2,sku2,EUR 799,some other Text,foo,\"t1;t2;t3;Üß\"\"Let's see if we support multi
      line value\"\"\",true
      """
    p2 =
      """
      #{@productType.name},productKey-2,myProduct2,my-slug2,1,sku3,USD 1899,,,,true
      ,,,,2,sku4,USD 1999,,,,false
      ,,,,3,sku5,USD 2099,,,,true
      ,,,,4,sku6,USD 2199,,,,false
      """
    csv =
      """
      #{header}
      #{p1}
      #{p2}
      """
    @importer.publishProducts = true
    @importer.import(csv)
    .then (result) =>
      console.log "import", result
      expect(_.size result).toBe 2
      expect(result[0]).toBe '[row 2] New product created.'
      expect(result[1]).toBe '[row 4] New product created.'
      file = '/tmp/impex.csv'
      @exporter.exportDefault(csv, file)
      .then (result) =>
        console.log "export", result
        expect(result).toBe 'Export done.'
        @client.products.all().fetch()
      .then (res) ->
        console.log "products %j", res.body
        fs.readFileAsync file, {encoding: 'utf8'}
      .then (content) ->
        console.log "export file content", content
        expect(content).toMatch header
        expect(content).toMatch p1
        expect(content).toMatch p2
        done()
    .catch (err) -> done _.prettify(err)

  it 'should import and re-export SEO attributes', (done) ->
    header = "productType,key,variantId,name.en,description.en,slug.en,metaTitle.en,metaDescription.en,metaKeywords.en,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,searchKeywords.en"
    p1 =
      """
      #{@productType.name},productKey,1,seoName,seoDescription,seoSlug,seoMetaTitle,seoMetaDescription,seoMetaKeywords,foo,new;search;keywords
      ,,2,,,,,,,bar
      """
    csv =
      """
      #{header}
      #{p1}
      """
    @importer.publishProducts = true
    @importer.import(csv)
    .then (result) =>
      console.log "import", result
      expect(_.size result).toBe 1
      expect(result[0]).toBe '[row 2] New product created.'
      file = '/tmp/impex.csv'
      @exporter.exportDefault(header, file)
      .then (result) ->
        console.log "export", result
        expect(result).toBe 'Export done.'
        fs.readFileAsync file, {encoding: 'utf8'}
      .then (content) ->
        console.log "export file content", content
        expect(content).toMatch header
        expect(content).toMatch p1
        done()
    .catch (err) -> done _.prettify(err)
