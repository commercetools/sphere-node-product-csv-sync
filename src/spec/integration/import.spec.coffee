_ = require('underscore')._
Import = require '../lib/import'
Q = require 'q'
Config = require '../config'

jasmine.getEnv().defaultTimeoutInterval = 30000

describe 'Import', ->
  beforeEach (done) ->
    @import = new Import Config
    @rest = @import.validator.rest

    values = [
      { key: 'x', label: 'X' }
      { key: 'y', label: 'Y' }
      { key: 'z', label: 'Z' }
    ]

    lvalues = [
      { key: 'aa', label: { en: 'AA', de: 'Aa' } }
      { key: 'bb', label: { en: 'BB', de: 'mäßig heiß bügeln' } }
      { key: 'cc', label: { en: 'CC', de: 'Cc' } }
    ]

    @productType =
      name: 'myType'
      description: 'foobar'
      attributes: [
        { name: 'descN', label: { de: 'descN' }, type: { name: 'text'}, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descU', label: { de: 'descU' }, type: { name: 'text'}, attributeConstraint: 'Unique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descCU1', label: { de: 'descCU1' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descCU2', label: { de: 'descCU2' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descS', label: { de: 'descS' }, type: { name: 'text'}, attributeConstraint: 'SameForAll', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'multiEnum', label: { de: 'multiEnum' }, type: { name: 'set', elementType: { name: 'enum', values: values } }, attributeConstraint: 'None', isRequired: false, isSearchable: false }
        { name: 'multiSamelEnum', label: { de: 'multiSamelEnum' }, type: { name: 'set', elementType: { name: 'lenum', values: lvalues } }, attributeConstraint: 'SameForAll', isRequired: false, isSearchable: false }
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

    @rest.GET '/products?staged=true&limit=0', (error, response, body) =>
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
              channel =
                key: 'retailerA'
                roles: [ 'InventorySupply' ]
              @rest.POST '/channels', JSON.stringify(channel), (error, response, body) ->
                done()
          .fail (msg) ->
            expect(true).toBe false
        .fail (msg) ->
          expect(true).toBe false

  describe '#import', ->
    it 'should import a simple product', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},myProduct,1,slug
        """
      @import.import csv, (res) ->
        expect(res.status).toBe true
        expect(res.message).toBe '[row 2] New product created.'
        done()

    it 'should import a product with prices', (done) ->
      csv =
        """
        productType,name,variantId,slug,prices
        #{@productType.id},myProduct,1,slug,EUR 899;CH-EUR 999;CH-USD 77777700 #retailerA
        """
      @import.import csv, (res) ->
        expect(res.status).toBe true
        expect(res.message).toBe '[row 2] New product created.'
        done()

    it 'should do nothing on 2nd import run', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},myProduct1,1,slug
        """
      @import.import csv, (res) ->
        expect(res.status).toBe true
        expect(res.message).toBe '[row 2] New product created.'
        im = new Import Config
        im.import csv, (res) ->
          expect(res.status).toBe true
          expect(res.message).toBe '[row 2] Product update not necessary.'
          done()

    it 'should update 2nd import run', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},myProductX,1,sluguniqe
        """
      @import.import csv, (res) =>
        expect(res.status).toBe true
        expect(res.message).toBe '[row 2] New product created.'
        im = new Import Config
        csv =
          """
          productType,name,variantId,slug
          #{@productType.id},CHANGED,1,sluguniqe
          """
        im.import csv, (res) ->
          expect(res.status).toBe true
          expect(res.message).toBe '[row 2] Product updated.'
          done()

    it 'should handle all kind of attributes and constraints', (done) ->
      csv =
        """
        productType,name,variantId,slug,descN,descU,descUC1,descUC2,descS
        #{@productType.id},myProduct1,1,slugi,,text1,foo,bar,same
        ,,2,slug,free,text2,foo,baz,same
        ,,3,slug,,text3,boo,baz,sameDifferentWhichWillBeIgnoredAsItIsDefined
        """
      @import.import csv, (res) =>
        expect(res.status).toBe true
        expect(res.message).toBe '[row 2] New product created.'
        im = new Import Config
        im.import csv, (res) =>
          expect(res.status).toBe true
          expect(res.message).toBe '[row 2] Product update not necessary.'
          csv =
            """
            productType,name,variantId,slug,descN,descU,descCU1,descCU2,descS
            #{@productType.id},myProduct1,1,slugi,,text4,boo,bar,STILL_SAME
            ,,2,slug,free,text2,foo,baz,STILL_SAME
            ,,3,slug,CHANGED,text3,boo,baz,STILL_SAME
            """
          im = new Import Config
          im.import csv, (res) ->
            expect(res.status).toBe true
            expect(res.message).toBe '[row 2] Product updated.'
            done()

    it 'should handle multiple products', (done) ->
      csv =
        """
        productType,name,variantId,slug,descU,descCU1
        #{@productType.id},myProduct1,1,slug1
        ,,2,slug12,x,y
        #{@productType.id},myProduct2,1,slug2
        #{@productType.id},myProduct3,1,slug3
        """
      @import.import csv, (res) ->
        expect(res.status).toBe true
        expect(_.size res.message).toBe 3
        expect(res.message['[row 2] New product created.']).toBe 1
        expect(res.message['[row 4] New product created.']).toBe 1
        expect(res.message['[row 5] New product created.']).toBe 1
        im = new Import Config
        im.import csv, (res) ->
          expect(res.status).toBe true
          expect(_.size res.message).toBe 3
          expect(res.message['[row 2] Product update not necessary.']).toBe 1
          expect(res.message['[row 4] Product update not necessary.']).toBe 1
          expect(res.message['[row 5] Product update not necessary.']).toBe 1
          done()

    it 'should handle set of enums', (done) ->
      csv =
        """
        productType,name,variantId,slug,multiEnum,descU,descCU1
        #{@productType.id},myProduct1,1,slug1,y;x,a,b
        ,,2,slug2,x;z,b,a
        """
      @import.import csv, (res) =>
        expect(res.status).toBe true
        expect(res.message).toBe '[row 2] New product created.'
        im = new Import Config
        im.import csv, (res) =>
          expect(res.status).toBe true
          expect(res.message).toBe '[row 2] Product update not necessary.'
          csv =
            """
            productType,name,variantId,slug,multiEnum,descU,descCU1
            #{@productType.id},myProduct1,1,slug1,y;x;z,a,b
            ,,2,slug2,z,b,a
            """
          im = new Import Config
          im.import csv, (res) ->
            expect(res.status).toBe true
            expect(res.message).toBe '[row 2] Product updated.'
            done()

    it 'should handle set of SameForAll enums', (done) ->
      csv =
        """
        productType,name,variantId,slug,sku,multiSamelEnum,descU,descCU1
        #{@productType.id},myProduct1,1,slug1,sku1,aa;bb;cc,a,b
        """
      @import.import csv, (res) =>
        expect(res.status).toBe true
        expect(res.message).toBe '[row 2] New product created.'
        im = new Import Config
        im.import csv, (res) =>
          expect(res.status).toBe true
          expect(res.message).toBe '[row 2] Product update not necessary.'
          csv =
            """
            productType,name,variantId,slug,sku,multiSamelEnum,descU,descCU1
            #{@productType.id},myProduct1,1,slug1,sku1,aa;bb;cc,a,b
            ,,2,slug2,,sku2,b,a
            ,,3,slug3,,sku3,c,c
            ,,4,slug4,,sku4,d,d
            ,,5,slug5,,sku5,e,e
            ,,6,slug6,,sku6,f,f
            ,,7,slug7,,sku7,g,g
            ,,8,slug8,,sku8,h,h
            ,,9,slug9,,sku9,i,i
            ,,10,slug10,,sku10,j,j
            ,,11,slug11,,sku11,k,k
            ,,12,slug12,,sku12,l,l
            ,,13,slug13,,sku13,m,m
            """
          im = new Import Config
          im.import csv, (res) ->
            expect(res.status).toBe true
            expect(res.message).toBe '[row 2] Product updated.'
            done()

    it 'should addVariant include SameForAll attribute change', (done) ->
      csv =
        """
        productType,name,variantId,slug,descU,descCU1,descS
        #{@productType.id},myProduct-1,1,slug-1,a,b,SAMESAME
        """
      @import.import csv, (res) =>
        expect(res.status).toBe true
        expect(res.message).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,descU,descCU1,descS
          #{@productType.id},myProduct-1,1,slug-1,a,b,SAMESAME_BUTDIFFERENT
          ,,2,slug-2,b,a,WE_WILL_IGNORE_THIS
          """
        im = new Import Config
        im.import csv, (res) ->
          expect(res.status).toBe true
          expect(res.message).toBe '[row 2] Product updated.'
          done()
