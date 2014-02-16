_ = require('underscore')._
fs = require 'fs'
Export = require '../lib/export'
Import = require '../lib/import'
Q = require 'q'
Config = require '../config'

jasmine.getEnv().defaultTimeoutInterval = 30000

describe 'Impex', ->
  beforeEach (done) ->
    @import = new Import Config
    @export = new Export Config
    @rest = @import.validator.rest

    @productType =
      name: 'myType'
      description: 'foobar'
      attributes: [
        { name: 'myAttrib', label: { name: 'myAttrib' }, type: { name: 'text'}, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
      ]

    deleteProduct = (product) =>
      deferred = Q.defer()
      @rest.DELETE "/products/#{product.id}?version=#{product.version}", (error, response, body) ->
        deferred.resolve response.statusCode
      deferred.promise

    deleteProductType = (productType) =>
      deferred = Q.defer()
      @rest.DELETE "/product-types/#{productType.id}?version=#{productType.version}", (error, response, body) ->
        deferred.resolve response.statusCode
      deferred.promise

    @rest.GET '/products?limit=0', (error, response, body) =>
      expect(response.statusCode).toBe 200
      parsed = JSON.parse body
      productDeletes = []
      typesDeletes = []
      for product in parsed.results
        productDeletes.push deleteProduct(product)
      @rest.GET '/product-types?limit=0', (error, response, body) =>
        expect(response.statusCode).toBe 200
        parsed = JSON.parse body
        for productType in parsed.results
          typesDeletes.push deleteProductType(productType)
        Q.all(productDeletes).then (statusCodes) =>
          Q.all(typesDeletes).then (statusCodes) =>
            @rest.POST '/product-types', JSON.stringify(@productType), (error, response, body) =>
              expect(response.statusCode).toBe 201
              @productType = JSON.parse body
              done()
          .fail (msg) ->
            expect(true).toBe false
        .fail (msg) ->
          expect(true).toBe false

  it 'should import and re-export a simple product', (done) ->
    csv =
      """
      productType,name.en,variantId,slug.en,myAttrib
      #{@productType.name},myProduct,1,my-slug,some Text
      """
    @import.import csv, (res) =>
      expect(res.status).toBe true
      expect(res.message).toBe 'New product created.'
      file = '/tmp/y1.csv'
      @export.export csv, file, (res) ->
        expect(res.status).toBe true
        expect(res.message).toBe 'Export done.'
        fs.readFile file, encoding: 'utf8', (err, content) ->
          expect(content).toBe csv
          done()
