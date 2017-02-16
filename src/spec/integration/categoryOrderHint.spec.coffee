_ = require 'underscore'
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
  masterVariant: {}

createImporter = ->
  im = new Import Config
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
  jasmine.getEnv().defaultTimeoutInterval = 90000 # 90 sec
  @export = new Export client: Config
  @importer = createImporter()
  @importer.suppressMissingHeaderWarning = true
  @client = @importer.client

  console.log 'create a category to work with'
  @client.categories.save(newCategory())
  .then (results) =>
    @category = results.body
    console.log "Created #{results.length} categories"

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
      console.log 'About to delete all categories'
      @client.categories.process (payload) =>
        console.log "Deleting #{payload.body.count} categories"
        Promise.map payload.body.results, (category) =>
          @client.categories.byId(category.id).delete(category.version)
      .then (results) =>
        console.log "Deleted #{results.length} categories"
        console.log "Delete all the created products"
        @client.products.process (payload) =>
          console.log "Deleting #{payload.body.count} products"
          Promise.map payload.body.results, (product) =>
            @client.products.byId(product.id).delete(product.version)
      .then (results) ->
        console.log "Deleted #{results.length} products"
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
          #{@productType.id},#{@product.id},#{@product.version},#{@product.slug},#{@category.externalId}: 0.9
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

    it 'should add another categoryOrderHint', (done) ->

      @client.categories.save(newCategory('Second category', 'externalId2'))
      .then (result) =>
        @newCategory = result.body
        productDraft = _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'

        productDraft.categories.push
          typeId: 'category'
          id: @newCategory.id

        @client.products.save(productDraft)
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
        @client.products.byId(@product.id).fetch()
      .then (result) =>
        product = result.body.masterData.staged
        expect(product.categoryOrderHints).toEqual
          "#{@category.id}": '0.5',
          "#{@newCategory.id}": '0.8'
        done()
      .catch (err) -> done _.prettify(err)

    it 'should add another categoryOrderHint when matching by SKU', (done) ->

      @client.categories.save(newCategory('Second category', 'externalId2'))
      .then (result) =>
        @newCategory = result.body
        productDraft = _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'

        productDraft.masterVariant.sku = '123'
        productDraft.categories.push
          typeId: 'category'
          id: @newCategory.id

        @client.products.save(productDraft)
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
        @client.products.byId(@product.id).fetch()
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

      @client.products.save(
        _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'
      )
      .then (result) =>
        @product = result.body
        @client.products.byId(@product.id).fetch()
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
      customExport = new Export
        client: Config
        categoryOrderHintBy: 'externalId'

      @client.products.save(
        _.extend {}, defaultProduct(@productType.id, @category.id),
          categoryOrderHints:
            "#{@category.id}": '0.5'
      )
      .then (result) =>
        @product = result.body
        @client.products.byId(@product.id).fetch()
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
