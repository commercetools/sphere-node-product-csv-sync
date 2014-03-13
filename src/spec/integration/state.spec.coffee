_ = require('underscore')._
fs = require 'fs'
Export = require '../lib/export'
Import = require '../lib/import'
Q = require 'q'
Config = require '../config'

jasmine.getEnv().defaultTimeoutInterval = 30000

describe 'State', ->
  beforeEach (done) ->
    @import = new Import Config
    @export = new Export Config
    @rest = @import.validator.rest

    @productType =
      name: 'myStateType'
      description: 'foobar'
      attributes: [
        { name: 'myAttrib', label: { name: 'myAttrib' }, type: { name: 'text'}, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
      ]

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

    @rest.GET '/products?limit=0', (error, response, body) =>
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
              done()
          .fail (msg) ->
            expect(true).toBe false
        .fail (msg) ->
          expect(true).toBe false

  it 'should unpublish products', (done) ->
    csv =
      """
      productType,name.en,slug.en,variantId,sku,myAttrib
      #{@productType.name},myProduct1,my-slug1,1,sku1,foo
      #{@productType.name},myProduct2,my-slug2,1,sku2,bar
      """
    @import.publishProducts = false
    @import.import csv, (res) =>
      console.log "state", res
      expect(res.status).toBe true
      expect(_.size res.message).toBe 2
      expect(res.message['[row 2] New product created.']).toBe 1
      expect(res.message['[row 3] New product created.']).toBe 1
      performProduct = -> true
      @import.publishOnly true, false, performProduct, (res) =>
        console.log "publish"
        expect(res.status).toBe true
        expect(res.message['[row 0] Product published.']).toBe 2
        @import.publishOnly false, false, performProduct, (res) =>
          console.log "unpublish"
          expect(res.status).toBe true
          expect(res.message['[row 0] Product unpublished.']).toBe 2
          done()
