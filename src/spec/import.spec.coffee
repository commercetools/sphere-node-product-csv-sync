_ = require('underscore')._
Import = require '../lib/import'
Q = require 'q'
Config = require '../config'

jasmine.getEnv().defaultTimeoutInterval = 5000

describe 'Import', ->
  beforeEach (done) ->
    @import = new Import Config
    @rest = @import.validator.rest
    
    @productType =
      name: 'myType'
      description: 'foobar'

    deleteProductType = (productType) =>
      deferred = Q.defer()
      @rest.DELETE "/product-types/#{productType.id}?version=#{productType.version}", (error, response, body) ->
        deferred.resolve "del" + response.statusCode
      deferred.promise

    @rest.GET '/product-types?limit=0', (error, response, body) =>
      expect(response.statusCode).toBe 200
      parsed = JSON.parse body
      deletes = []
      for productType in parsed.results
        deletes.push deleteProductType(productType)
      Q.all(deletes).then (statusCodes) =>
        @rest.POST '/product-types', JSON.stringify(@productType), (error, response, body) =>
          expect(response.statusCode).toBe 201
          @productType = JSON.parse body
          done()
      .fail (msg) ->
        console.log msg
        expect(true).toBe false

  describe '#import', ->
    it 'should work for a simple product', (done) ->
      csv ="
productType,name,variantId\n
myType,myProduct,1"
      @import.import csv, (res) ->
        expect(res).toBe true
        done()