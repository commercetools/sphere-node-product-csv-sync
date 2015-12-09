_ = require 'underscore'
debug = require('debug')('spec-integration:categoryOrderHints')
_.mixin require('underscore-mixins')
{Import} = require '../../lib/main'
Config = require '../../config'
TestHelpers = require './testhelpers'
Promise = require 'bluebird'

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

describe 'Import', ->

  beforeEach (done) ->
    jasmine.getEnv().defaultTimeoutInterval = 90000 # 90 sec
    @importer = createImporter()
    @importer.validator.suppressMissingHeaderWarning = true
    @client = @importer.client

    debug 'create a category to work with'
    @client.categories.save(newCategory())
    .then (results) =>
      @categoryId = results.body.id
      debug "Created #{results.length} categories"

      @productType = TestHelpers.mockProductType()
      TestHelpers.setupProductType(@client, @productType)
    .then (result) =>
      @productType = result
      @client.channels.ensure(CHANNEL_KEY, 'InventorySupply')
    .then -> done()
    .catch (error) -> done(_.prettify(error))

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

  it 'should update categoryOrderHints', (done) ->

    @client.products.save(
      name:
        en: 'test product'
      productType:
        typeId: 'product-type'
        id: @productType.id
      slug:
        en: TestHelpers.uniqueId 'slug-'
      categories: [
        typeId: 'category'
        id: @categoryId
      ]
    )
    .then (result) =>
      @product = result.body
      csv =
        """
        productType,id,version,slug,categoryOrderHints
        #{@productType.id},#{@product.id},#{@product.version},#{@product.slug},#{@categoryId}:0.5
        """
      im = createImporter(
        continueOnProblems: true
      )
      im.import(csv)
    .then (result) =>
      expect(result[0]).toBe '[row 2] Product updated.'
      @client.products.byId(@product.id).fetch()
    .then (result) =>
      expect(result.body.masterData.staged.categoryOrderHints).toEqual {"#{@categoryId}": '0.5'}
      done()
    .catch (err) -> done _.prettify(err)
