_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')
Config = require '../../config'
TestHelpers = require './testhelpers'
{Export} = require '../../main'

describe 'Export integration tests', ->

  beforeEach (done) ->
    @export = new Export Config
    @client = @export.client

    values = [
      { key: 'x', label: 'X' }
      { key: 'y', label: 'Y' }
      { key: 'z', label: 'Z' }
    ]

    @productType =
      name: 'myExportType'
      description: 'foobar'
      attributes: [
        { name: 'descN', label: { name: 'descN' }, type: { name: 'text'}, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descU', label: { name: 'descU' }, type: { name: 'text'}, attributeConstraint: 'Unique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descCU1', label: { name: 'descCU1' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descCU2', label: { name: 'descCU2' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descS', label: { name: 'descS' }, type: { name: 'text'}, attributeConstraint: 'SameForAll', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'multiEnum', label: { name: 'multiEnum' }, type: { name: 'set', elementType: { name: 'enum', values: values } }, attributeConstraint: 'None', isRequired: false, isSearchable: false }
      ]

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
    .fail (err) ->
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
    .fail (err) ->
      done(_.prettify err)
    .done()

  it 'should export based on minimum template', (done) ->
    template =
      '''
      productType,name,variantId
      '''
    file = '/tmp/output.csv'
    expectedCSV =
      """
      productType,name,variantId
      myExportType,,1
      """
    @export.export(template, file)
    .then (result) ->
      expect(result).toBe 'Export done.'
      fs.readFile file, encoding: 'utf8', (err, content) ->
        expect(content).toBe expectedCSV
        done()
    .fail (err) ->
      done(_.prettify err)
    .done()
  , 20000 # 20sec
