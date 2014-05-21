fs = require 'fs'
Q = require 'q'
_ = require 'underscore'
_.mixin require('sphere-node-utils')._u
Export = require '../../lib/export'
Config = require '../../config'
TestHelpers = require './testhelpers'

jasmine.getEnv().defaultTimeoutInterval = 60000

describe 'Export', ->
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

    TestHelpers.setup(@client, @productType, @product).then (result) ->
      done()
    .fail (err) ->
      done(_.prettify err)
    .done()


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
      expect(err[1]).toBe "Can't find necessary base header 'variantId'!"
      done()
    .done()

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
