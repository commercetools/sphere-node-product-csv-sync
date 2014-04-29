fs = require 'fs'
Q = require 'q'
_ = require 'underscore'
_.mixin require('sphere-node-utils')._u
Export = require '../../lib/export'
Config = require '../../config'

jasmine.getEnv().defaultTimeoutInterval = 30000

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

    @client.products.all().fetch()
    .then (result) =>
      deletions = _.map result.body.results, (product) =>
        deferred = Q.defer()
        data =
          id: product.id
          version: product.version
          actions: [
            action: 'unpublish'
          ]
        @client._rest.POST "/products/#{product.id}", data, (error, response, body) =>
          console.log "res", response.statusCode
          if response.statusCode is 200
            product.version = body.version
          @client.products.byId(product.id).delete(product.version)
          .then (result) ->
            console.log "Del %j", result
            deferred.resolve true
          .fail (err) ->
            deferred.reject err
        deferred.promise
      Q.all(deletions)
    .then =>
      @client.productTypes.all().fetch()
    .then (result) =>
      deletions = _.map result.body.results, (productType) =>
        @client.productTypes.byId(productType.id).delete(productType.version)
      Q.all(deletions)
    .then =>
      @client.productTypes.create(@productType)
    .then (result) =>
      @product.productType.id = result.body.id
      @client.products.create(@product)
    .then (result) ->
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
      done 'Export should fail!'
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
