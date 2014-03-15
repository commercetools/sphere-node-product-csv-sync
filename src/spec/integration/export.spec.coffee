_ = require('underscore')._
fs = require 'fs'
Export = require '../lib/export'
Q = require 'q'
Config = require '../config'

jasmine.getEnv().defaultTimeoutInterval = 30000

describe 'Export', ->
  beforeEach (done) ->
    @export = new Export Config
    @rest = @export.rest

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

    deleteProduct = (product) =>
      deferred = Q.defer()
      data =
        id: product.id
        version: product.version
        actions: [
          action: 'unpublish'
        ]
      @rest.POST "/products/#{product.id}", JSON.stringify(data), (error, response, body) =>
        if response.statusCode is 200
          product.version = body.version
        @rest.DELETE "/products/#{product.id}?version=#{product.version}", (error, response, body) ->
          deferred.resolve response.statusCode
      deferred.promise

    deleteProductType = (productType) =>
      deferred = Q.defer()
      @rest.DELETE "/product-types/#{productType.id}?version=#{productType.version}", (error, response, body) ->
        deferred.resolve response.statusCode
      deferred.promise

    @rest.GET '/products', (error, response, body) =>
      expect(response.statusCode).toBe 200
      productDeletes = []
      typesDeletes = []
      for product in body.results
        productDeletes.push deleteProduct(product)
      @rest.GET '/product-types?limit=0', (error, response, body) =>
        expect(response.statusCode).toBe 200
        for productType in body.results
          typesDeletes.push deleteProductType(productType)
        Q.all(productDeletes).then (statusCodes) =>
          Q.all(typesDeletes).then (statusCodes) =>
            @rest.POST '/product-types', JSON.stringify(@productType), (error, response, body) =>
              expect(response.statusCode).toBe 201
              @productType = body
              @product.productType.id = @productType.id
              @rest.POST '/products', JSON.stringify(@product), (error, response, body) ->
                expect(response.statusCode).toBe 201
                done()
          .fail (msg) ->
            expect(true).toBe false
        .fail (msg) ->
          expect(true).toBe false

  it 'should inform about a bad header in the template', (done) ->
    template =
      '''
      productType,name,name
      '''
    @export.export template, null, (res) ->
      expect(res.status).toBe false
      expect(res.message['There are duplicate header entries!']).toBe 1
      expect(res.message["Can't find necessary base header 'variantId'!"]).toBe 1
      done()

  it 'should inform that there are no products', (done) ->
    @export.queryString = 'staged=false'
    template =
      '''
      productType,name,variantId
      '''
    @export.export template, '/tmp/foo.csv', (res) ->
      expect(res.status).toBe true
      expect(res.message).toBe 'No products found.'
      done()

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
    @export.export template, file, (res) ->
      expect(res.status).toBe true
      expect(res.message).toBe 'Export done.'
      fs.readFile file, encoding: 'utf8', (err, content) ->
        expect(content).toBe expectedCSV
        done()
