_ = require('underscore')._
Import = require '../lib/import'
Q = require 'q'
Config = require '../config'

jasmine.getEnv().defaultTimeoutInterval = 20000

describe 'Import', ->
  beforeEach (done) ->
    @import = new Import Config
    @rest = @import.validator.rest
    
    @productType =
      name: 'myType'
      description: 'foobar'

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
      deletes = []
      for product in parsed.results
        deletes.push deleteProduct(product)
      @rest.GET '/product-types?limit=0', (error, response, body) =>
        expect(response.statusCode).toBe 200
        parsed = JSON.parse body
        for productType in parsed.results
          deletes.push deleteProductType(productType)
        Q.all(deletes).then (statusCodes) =>
          @rest.POST '/product-types', JSON.stringify(@productType), (error, response, body) =>
            expect(response.statusCode).toBe 201
            @productType = JSON.parse body
            done()
        .fail (msg) ->
          expect(true).toBe false

  describe '#import', ->
    it 'should import for a simple product', (done) ->
      csv ="
productType,name,variantId,slug\n
myType,myProduct,1,slug"
      @import.import csv, (res) ->
        expect(res.status).toBe true
        expect(res.message).toBe 'New product created.'
        done()

    it 'should do nothing on 2nd import run', (done) ->
      csv ="
productType,name,variantId,slug\n
myType,myProduct1,1,slug"
      @import.import csv, (res) ->
        expect(res.status).toBe true
        expect(res.message).toBe 'New product created.'
        im = new Import Config
        im.import csv, (res) ->
          expect(res.status).toBe true
          expect(res.message).toBe 'Product update not necessary.'
          done()