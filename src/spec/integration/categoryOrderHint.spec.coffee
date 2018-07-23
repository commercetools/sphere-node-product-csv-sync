_ = require 'underscore'
_.mixin require('underscore-mixins')
{Import, Export} = require '../../lib/main'
Config = require '../../config'
TestHelpers = require './testhelpers'
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')

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

defaultProduct = (productTypeId, categoryId) ->
  name:
    en: 'test product'
  productType:
    typeId: 'product-type'
    id: productTypeId
  slug:
    en: TestHelpers.uniqueId 'slug-'
  categories: [
    typeId: 'category'
    id: categoryId
  ]
  masterVariant: {}

createImporter = ->
  im = new Import {
    authConfig: authConfig
    httpConfig: httpConfig
    userAgentConfig: userAgentConfig
  }
  im.allowRemovalOfVariants = true
  im.suppressMissingHeaderWarning = true
  im

CHANNEL_KEY = 'retailerA'

uniqueId = (prefix) ->
  _.uniqueId "#{prefix}#{new Date().getTime()}_"

newCategory = (name = 'Category name', externalId = 'externalCategoryId') ->
  name:
    en: name
  slug:
    en: uniqueId 'c'
  externalId: externalId

prepareCategoryAndProduct = (done) ->
  jasmine.DEFAULT_TIMEOUT_INTERVAL = 120000 # 2mins
  @export = new Export {
    authConfig: authConfig
    httpConfig: httpConfig
    userAgentConfig: userAgentConfig
  }
  @importer = createImporter()
  @importer.suppressMissingHeaderWarning = true
  @client = @importer.client

  console.log 'create a category to work with'
  service = TestHelpers.createService(project_key, 'categories')
  request = {
    uri: service.build()
    method: 'POST'
    body: newCategory()
  }
  @client.execute request
  .then (results) =>
    @category = results.body
    console.log "Created #{results.length} categories"

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
  .catch (error) -> done(_.prettify(error))

describe 'categoryOrderHints', ->

  describe 'Import', ->

    beforeEach prepareCategoryAndProduct

    afterEach (done) ->
      console.log 'About to delete all categories'
      service = TestHelpers.createService(project_key, 'categories')
      request = {
        uri: service.build()
        method: 'GET'
      }
      @client.process request, (payload) =>
        console.log "Deleting #{payload.body.count} categories"
        Promise.map payload.body.results, (category) =>
          service = TestHelpers.createService(project_key, 'categories')
          request = {
            uri: service
              .byId(category.id)
              .withVersion(category.version)
              .build()
            method: 'DELETE'
          }
          @client.execute request
      .then (results) =>
        console.log "Deleted #{results.length} categories"
        console.log "Delete all the created products"
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.build()
          method: 'GET'
        }
        @client.process request, (payload) =>
          console.log "Deleting #{payload.body.count} products"
          Promise.map payload.body.results, (product) =>
            service = TestHelpers.createService(project_key, 'products')
            request = {
              uri: service
                .byId(product.id)
                .withVersion(product.version)
                .build()
              method: 'DELETE'
            }
            @client.execute request
      .then (results) ->
        console.log "Deleted #{results.length} products"
        done()
      .catch (error) -> done(_.prettify(error))
    , 90000 # 90secs

    it 'should add categoryOrderHints', (done) ->
      service = TestHelpers.createService(project_key, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: defaultProduct(@productType.id, @category.id)
      }
      @client.execute request
      .then (result) =>
        @product = result.body
        csv =
          """
          productType,id,version,slug,categoryOrderHints
          #{@productType.id},#{@product.id},#{@product.version},#{@product.slug},#{@category.id}:0.5
          """
        im = createImporter(
          continueOnProblems: true
        )
        im.import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.5'}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should add categoryOrderHints when using an external category id', (done) ->
      service = TestHelpers.createService(project_key, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: defaultProduct(@productType.id, @category.id)
      }
      @client.execute request
      .then (result) =>
        @product = result.body
        csv =
          """
          productType,id,version,slug,categoryOrderHints
          #{@productType.id},#{@product.id},#{@product.version},#{@product.slug},externalCategoryId:0.5
          """
        im = createImporter(
          continueOnProblems: true
        )
        im.import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.5'}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should add categoryOrderHints when using an category name', (done) ->
      service = TestHelpers.createService(project_key, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: defaultProduct(@productType.id, @category.id)
      }
      @client.execute request
      .then (result) =>
        @product = result.body
        csv =
          """
          productType,id,version,slug,categoryOrderHints
          #{@productType.id},#{@product.id},#{@product.version},#{@product.slug},#{@category.name.en}:0.5
          """
        im = createImporter(
          continueOnProblems: true
        )
        im.import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.5'}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should add categoryOrderHints when using an category slug', (done) ->
      service = TestHelpers.createService(project_key, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: defaultProduct(@productType.id, @category.id)
      }
      @client.execute request
      .then (result) =>
        @product = result.body
        csv =
          """
          productType,id,version,slug,categoryOrderHints
          #{@productType.id},#{@product.id},#{@product.version},#{@product.slug},#{@category.slug.en}:0.5
          """
        im = createImporter(
          continueOnProblems: true
        )
        im.import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.5'}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should remove categoryOrderHints', (done) ->
      service = TestHelpers.createService(project_key, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'
      }
      @client.execute request
      .then (result) =>
        @product = result.body
        csv =
          """
          productType,id,version,slug,categoryOrderHints
          #{@productType.id},#{@product.id},#{@product.version},#{@product.slug},
          """
        im = createImporter(
          continueOnProblems: true
        )
        im.import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should change categoryOrderHints', (done) ->
      service = TestHelpers.createService(project_key, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'
      }
      @client.execute request
      .then (result) =>
        @product = result.body
        csv =
          """
          productType,id,version,slug,categoryOrderHints
          #{@productType.id},#{@product.id},#{@product.version},#{@product.slug},#{@category.externalId}: 0.9
          """
        im = createImporter(
          continueOnProblems: true
        )
        im.import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.9'}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should add another categoryOrderHint', (done) ->
      service = TestHelpers.createService(project_key, 'categories')
      request = {
        uri: service.build()
        method: 'POST'
        body: newCategory('Second category', 'externalId2')
      }
      @client.execute request
      .then (result) =>
        @newCategory = result.body
        productDraft = _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'

        productDraft.categories.push
          typeId: 'category'
          id: @newCategory.id
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.build()
          method: 'POST'
          body: productDraft
        }
        @client.execute request
      .then (result) =>
        @product = result.body
        csv =
          """
          productType,id,version,categoryOrderHints
          #{@productType.id},#{@product.id},#{@product.version},#{@newCategory.externalId}: 0.8
          """

        im = createImporter(
          continueOnProblems: true
        )
        im.mergeCategoryOrderHints = true
        im.import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        product = result.body.masterData.staged
        expect(product.categoryOrderHints).toEqual
          "#{@category.id}": '0.5',
          "#{@newCategory.id}": '0.8'
        done()
      .catch (err) -> done _.prettify(err)

    it 'should add another categoryOrderHint when matching by SKU', (done) ->
      service = TestHelpers.createService(project_key, 'categories')
      request = {
        uri: service.build()
        method: 'POST'
        body: newCategory('Second category', 'externalId2')
      }
      @client.execute request
      .then (result) =>
        @newCategory = result.body
        productDraft = _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'

        productDraft.masterVariant.sku = '123'
        productDraft.categories.push
          typeId: 'category'
          id: @newCategory.id
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.build()
          method: 'POST'
          body: productDraft
        }
        @client.execute request
      .then (result) =>
        @product = result.body
        csv =
          """
          productType,sku,categoryOrderHints
          #{@productType.id},#{@product.masterData.staged.masterVariant.sku},#{@newCategory.externalId}: 0.8
          """
        im = createImporter(
          continueOnProblems: true
        )
        im.mergeCategoryOrderHints = true
        im.import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        product = result.body.masterData.staged
        expect(product.categoryOrderHints).toEqual
          "#{@category.id}": '0.5',
          "#{@newCategory.id}": '0.8'
        done()
      .catch (err) -> done _.prettify(err)

  describe 'Export', ->

    beforeEach prepareCategoryAndProduct

    it 'should export categoryOrderHints', (done) ->
      service = TestHelpers.createService(project_key, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'
      }
      @client.execute request
      .then (result) =>
        @product = result.body
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then =>
        template =
          """
          productType,id,variantId,categoryOrderHints
          """
        file = '/tmp/output.csv'
        expectedCSV =
          """
          productType,id,variantId,categoryOrderHints
          #{@productType.name},#{@product.id},#{@product.lastVariantId},#{@category.id}:0.5

          """
        @export.exportDefault(template, file)
        .then (result) ->
          expect(result).toBe 'Export done.'
          fs.readFileAsync file, {encoding: 'utf8'}
        .then (content) ->
          expect(content).toBe expectedCSV
          done()
        .catch (err) -> done _.prettify(err)

    it 'should export categoryOrderHints with category externalId', (done) ->
      customExport = new Export {
        authConfig: authConfig
        httpConfig: httpConfig
        userAgentConfig: userAgentConfig
        categoryOrderHintBy: 'externalId'
      }
      service = TestHelpers.createService(project_key, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'
      }
      @client.execute request
      .then (result) =>
        @product = result.body
        service = TestHelpers.createService(project_key, 'products')
        request = {
          uri: service.byId(@product.id).build()
          method: 'GET'
        }
        @client.execute request
      .then =>
        template =
          """
          productType,id,variantId,categoryOrderHints
          """
        file = '/tmp/output.csv'
        expectedCSV =
          """
          productType,id,variantId,categoryOrderHints
          #{@productType.name},#{@product.id},#{@product.lastVariantId},#{@category.externalId}:0.5

          """

        customExport.exportDefault(template, file)
        .then (result) ->
          expect(result).toBe 'Export done.'
          fs.readFileAsync file, {encoding: 'utf8'}
        .then (content) ->
          expect(content).toBe expectedCSV
          done()
      .catch (err) -> done _.prettify(err)
