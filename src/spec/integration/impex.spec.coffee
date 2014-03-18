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
        { name: 'myAttrib', label: { name: 'myAttrib' }, type: { name: 'ltext'}, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'sfa', label: { name: 'sfa' }, type: { name: 'text'}, attributeConstraint: 'SameForAll', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'myMultiText', label: { name: 'myMultiText' }, type: { name: 'set', elementType: { name: 'text'} }, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
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

    @rest.GET '/products?staged=false', (error, response, body) =>
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

  it 'should import and re-export a simple product', (done) ->
    header = 'productType,name.en,slug.en,variantId,sku,prices,myAttrib.en,sfa,myMultiText'
    p1 =
      """
      #{@productType.name},myProduct1,my-slug1,1,sku1,FR-EUR 999;CHF 1099,some Text,foo
      ,,,2,sku2,EUR 799,some other Text,foo,t1;t2;t3;Üß"Let's see if we support multi
      line value"
      """
    p2 =
      """
      #{@productType.name},myProduct2,my-slug2,1,sku3,USD 1899
      ,,,2,sku4,USD 1999
      ,,,3,sku5,USD 2099
      ,,,4,,USD 2199
      """
    csv =
      """
      #{header}
      #{p1}
      #{p2}
      """
    @import.publishProducts = true
    @import.import csv, (res) =>
      console.log "import", res
      expect(res.status).toBe true
      expect(_.size res.message).toBe 2
      expect(res.message['[row 2] New product created.']).toBe 1
      expect(res.message['[row 4] New product created.']).toBe 1
      file = '/tmp/impex.csv'
      @export.queryString = ''
      @export.export csv, file, (res) ->
        console.log "export", res
        expect(res.status).toBe true
        expect(res.message).toBe 'Export done.'
        fs.readFile file, encoding: 'utf8', (err, content) ->
          console.log "export file content", content
          expect(content).toMatch header
          expect(content).toMatch p1
          expect(content).toMatch p2
          done()
