_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')
Config = require '../../config'
TestHelpers = require './testhelpers'
{Export} = require '../../lib/main'

describe 'Export integration tests', ->

  beforeEach (done) ->
    @export = new Export client: Config
    @client = @export.client

    values = [
      { key: 'x', label: 'X' }
      { key: 'y', label: 'Y' }
      { key: 'z', label: 'Z' }
    ]

    @productType = TestHelpers.mockProductType()

    @product =
      productType:
        typeId: 'product-type'
        id: 'TODO'
      name:
        en: 'Foo'
      slug:
        en: 'foo'

    TestHelpers.setupProductType(@client, @productType, @product)
    .then -> done()
    .catch (err) -> done _.prettify(err)
    .done()
  , 30000 # 30sec


  it 'should inform about a bad header in the template', (done) ->
    template =
      '''
      productType,name,name
      '''
    @export.export(template, null)
    .then (result) ->
      done('Export should fail!')
    .catch (err) ->
      expect(_.size err).toBe 2
      expect(err[0]).toBe 'There are duplicate header entries!'
      expect(err[1]).toBe "You need either the column 'variantId' or 'sku' to identify your variants!"
      done()
    .done()
  , 20000 # 20sec

  it 'should inform that there are no products', (done) ->
    template =
      '''
      productType,name,variantId
      '''
    @export.export(template, '/tmp/foo.csv', false)
    .then (result) ->
      expect(result).toBe 'No products found.'
      done()
    .catch (err) -> done _.prettify(err)
    .done()
  , 20000 # 20sec

  it 'should export based on minimum template', (done) ->
    template =
      '''
      productType,name,variantId
      '''
    file = '/tmp/output.csv'
    expectedCSV =
      """
      productType,name,variantId
      #{@productType.name},,1
      """
    @export.export(template, file)
    .then (result) ->
      expect(result).toBe 'Export done.'
      fs.readFileAsync file, {encoding: 'utf8'}
    .then (content) ->
      expect(content).toBe expectedCSV
      done()
    .catch (err) -> done _.prettify(err)
    .done()
  , 20000 # 20sec
