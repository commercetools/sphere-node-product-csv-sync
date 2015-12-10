_ = require 'underscore'
debug = require('debug')('spec-integration:categoryOrderHints')
_.mixin require('underscore-mixins')
{Import, Export} = require '../../lib/main'
Config = require '../../config'
TestHelpers = require './testhelpers'
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')

defaultProduct = (productTypeId, categoryId) =>
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

createImporter = ->
  im = new Import Config
  im.allowRemovalOfVariants = true
  im.validator.suppressMissingHeaderWarning = true
  im

CHANNEL_KEY = 'retailerA'

uniqueId = (prefix) ->
  _.uniqueId "#{prefix}#{new Date().getTime()}_"

newCategory = (name = 'Category name') ->
  name:
    en: name
  slug:
    en: uniqueId 'c'
  externalId: 'externalCategoryId'

prepareCategoryAndProduct = (done) ->
  jasmine.getEnv().defaultTimeoutInterval = 90000 # 90 sec
  @export = new Export client: Config
  @importer = createImporter()
  @importer.validator.suppressMissingHeaderWarning = true
  @client = @importer.client

  debug 'create a category to work with'
  @client.categories.save(newCategory())
  .then (results) =>
    @category = results.body
    debug "Created #{results.length} categories"

    @productType = TestHelpers.mockProductType()
    TestHelpers.setupProductType(@client, @productType)
  .then (result) =>
    @productType = result
    @client.channels.ensure(CHANNEL_KEY, 'InventorySupply')
  .then -> done()
  .catch (error) -> done(_.prettify(error))

describe 'categoryOrderHints', ->

  describe 'Import', ->

    beforeEach prepareCategoryAndProduct

    afterEach (done) ->
      debug 'About to delete all categories'
      @client.categories.process (payload) =>
        debug "Deleting #{payload.body.count} categories"
        Promise.map payload.body.results, (category) =>
          @client.categories.byId(category.id).delete(category.version)
      .then (results) =>
        debug "Deleted #{results.length} categories"
        debug "Delete all the created products"
        @client.products.process (payload) =>
          debug "Deleting #{payload.body.count} products"
          Promise.map payload.body.results, (product) =>
            @client.products.byId(product.id).delete(product.version)
      .then (results) ->
        debug "Deleted #{results.length} products"
        done()
      .catch (error) -> done(_.prettify(error))
    , 60000 # 1min

    it 'should add categoryOrderHints', (done) ->

      @client.products.save(defaultProduct(@productType.id, @category.id))
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
        @client.products.byId(@product.id).fetch()
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.5'}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should add categoryOrderHints when using an external category id', (done) ->

      @client.products.save(defaultProduct(@productType.id, @category.id))
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
        @client.products.byId(@product.id).fetch()
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.5'}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should add categoryOrderHints when using an category name', (done) ->

      @client.products.save(defaultProduct(@productType.id, @category.id))
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
        @client.products.byId(@product.id).fetch()
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.5'}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should add categoryOrderHints when using an category slug', (done) ->

      @client.products.save(defaultProduct(@productType.id, @category.id))
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
        @client.products.byId(@product.id).fetch()
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.5'}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should remove categoryOrderHints', (done) ->

      @client.products.save(
        _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'
      )
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
        @client.products.byId(@product.id).fetch()
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {}
        done()
      .catch (err) -> done _.prettify(err)

    it 'should change categoryOrderHints', (done) ->

      @client.products.save(
        _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'
      )
      .then (result) =>
        @product = result.body
        csv =
          """
          productType,id,version,slug,categoryOrderHints
          #{@productType.id},#{@product.id},#{@product.version},#{@product.slug},#{@category.id}: 0.9
          """
        im = createImporter(
          continueOnProblems: true
        )
        im.import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product updated.'
        @client.products.byId(@product.id).fetch()
      .then (result) =>
        expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@category.id}": '0.9'}
        done()
      .catch (err) -> done _.prettify(err)

  describe 'Export', ->

    beforeEach prepareCategoryAndProduct

    it 'should export categoryOrderHints', (done) ->

      @client.products.save(
        _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'
      )
      .then (result) =>
        @product = result.body
        @client.products.byId(@product.id).fetch()
      .then (result) =>
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
        @export.export(template, file)
        .then (result) ->
          expect(result).toBe 'Export done.'
          fs.readFileAsync file, {encoding: 'utf8'}
        .then (content) ->
          expect(content).toBe expectedCSV
          done()
        .catch (err) -> done _.prettify(err)
