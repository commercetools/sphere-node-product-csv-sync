_ = require('underscore')._
Import = require '../lib/import'
Q = require 'q'
Config = require '../config'

jasmine.getEnv().defaultTimeoutInterval = 20000

xdescribe 'Import', ->
  beforeEach (done) ->
    @import = new Import Config
    @rest = @import.validator.rest
    
    @productType =
      name: 'myType'
      description: 'foobar'
      attributes: [
        { name: 'descN', label: { name: 'descN' }, type: { name: 'text'}, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descU', label: { name: 'descU' }, type: { name: 'text'}, attributeConstraint: 'Unique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descCU1', label: { name: 'descCU1' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descCU2', label: { name: 'descCU2' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descS', label: { name: 'descS' }, type: { name: 'text'}, attributeConstraint: 'SameForAll', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
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

  describe '#import', ->
    it 'should import a simple product', (done) ->
      csv = "
productType,name,variantId,slug\n
#{@productType.id},myProduct,1,slug"
      @import.import csv, (res) ->
        expect(res.status).toBe true
        expect(res.message).toBe 'New product created.'
        done()

    it 'should do nothing on 2nd import run', (done) ->
      csv = "
productType,name,variantId,slug\n
#{@productType.id},myProduct1,1,slug"
      @import.import csv, (res) ->
        expect(res.status).toBe true
        expect(res.message).toBe 'New product created.'
        im = new Import Config
        im.import csv, (res) ->
          expect(res.status).toBe true
          expect(res.message).toBe 'Product update not necessary.'
          done()

    it 'should update 2nd import run', (done) ->
      csv = "
productType,name,variantId,slug\n
#{@productType.id},myProductX,1,sluguniqe"
      @import.import csv, (res) =>
        expect(res.status).toBe true
        expect(res.message).toBe 'New product created.'
        im = new Import Config
        csv = "
productType,name,variantId,slug\n
#{@productType.id},CHANGED,1,sluguniqe"
        im.import csv, (res) ->
          expect(res.status).toBe true
          expect(res.message).toBe 'Product updated.'
          done()

    it 'should handle all kind of attributes and constraints', (done) ->
      csv = "
productType,name,variantId,slug,descN,descU,descUC1,descUC2,descS\n
#{@productType.id},myProduct1,1,slugi,,text1,foo,bar,same\n
,,2,slug,free,text2,foo,baz,same\n
,,3,slug,,text3,boo,baz,same"
      @import.import csv, (res) =>
        expect(res.status).toBe true
        expect(res.message).toBe 'New product created.'
        im = new Import Config
        im.import csv, (res) =>
          expect(res.status).toBe true
          expect(res.message).toBe 'Product update not necessary.'
          csv = "
productType,name,variantId,slug,descN,descU,descCU1,descCU2,descS\n
#{@productType.id},myProduct1,1,slugi,,text4,boo,bar,STILL_SAME\n
,,2,slug,free,text2,foo,baz,STILL_SAME\n
,,3,slug,CHANGED,text3,boo,baz,STILL_SAME"
          im = new Import Config
          im.import csv, (res) ->
            expect(res.status).toBe true
            expect(res.message).toBe 'Product updated.'
            done()

    it 'should handle multiple products', (done) ->
      csv = "
productType,name,variantId,slug,descU,descCU1\n
#{@productType.id},myProduct1,1,slug1\n
,,2,slug12,x,y\n
#{@productType.id},myProduct2,1,slug2\n
#{@productType.id},myProduct3,1,slug3"
      @import.import csv, (res) ->
        expect(res.status).toBe true
        expect(res.message['New product created.']).toBe 3
        im = new Import Config
        im.import csv, (res) ->
          expect(res.status).toBe true
          expect(res.message['Product update not necessary.']).toBe 3
          done()
