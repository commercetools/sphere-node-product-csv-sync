Promise = require 'bluebird'
fetch = require 'node-fetch'
_ = require 'underscore'
archiver = require 'archiver'
_.mixin require('underscore-mixins')
iconv = require 'iconv-lite'
{ Import } = require '../../lib/main'
Config = require '../../config'
TestHelpers = require './testhelpers'
cuid = require 'cuid'
path = require 'path'
tmp = require 'tmp'
fs = Promise.promisifyAll require('fs')
# will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup()

TEXT_ATTRIBUTE_NONE = 'attr-text-n'
LTEXT_ATTRIBUTE_COMBINATION_UNIQUE = 'attr-ltext-cu'
NUMBER_ATTRIBUTE_COMBINATION_UNIQUE = 'attr-number-cu'
ENUM_ATTRIBUTE_SAME_FOR_ALL = 'attr-enum-sfa'
SET_ATTRIBUTE_TEXT_UNIQUE = 'attr-set-text-u'
SET_ATTRIBUTE_ENUM_NONE = 'attr-set-enum-n'
SET_ATTRIBUTE_LENUM_SAME_FOR_ALL = 'attr-set-lenum-sfa'
REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE = 'attr-ref-product-type-n'

{ client_id, client_secret, project_key } = Config.config
authConfig = {
  host: 'https://auth.sphere.io'
  projectKey: project_key
  credentials: {
    clientId: client_id
    clientSecret: client_secret
  }
  fetch: fetch
}
httpConfig = { host: 'https://api.sphere.io', fetch: fetch }
userAgentConfig = {}
createImporter = ->
  im = new Import {
    authConfig: authConfig
    httpConfig: httpConfig
    userAgentConfig: userAgentConfig
  }
  im.matchBy = 'sku'
  im.allowRemovalOfVariants = true
  im.suppressMissingHeaderWarning = true
  im

CHANNEL_KEY = 'retailerA'

describe 'Import integration test', ->
  beforeAll (done) ->
    @client = createImporter().client
    TestHelpers.ensureChannels(@client, project_key, CHANNEL_KEY)
    .then =>
      TestHelpers.ensurePreviousState(@client, project_key)
    .then =>
      TestHelpers.ensureNextState(@client, project_key)
    .then -> done()

  beforeEach (done) ->
    jasmine.DEFAULT_TIMEOUT_INTERVAL = 360000 # 3mins
    @importer = createImporter()
    @client = @importer.client

    @productType = TestHelpers.mockProductType()
    @productType.attributes.push({
      name: 'productType'
      label:
        en: 'productType'
      isRequired: false
      type:
        name: 'text'
      attributeConstraint: 'None'
      isSearchable: false
      inputHint: 'SingleLine'
      displayGroup: 'Other'
    })

    @productType.attributes.push({
      name: 'description'
      label:
        en: 'desc'
      isRequired: false
      type:
        name: 'ltext'
      attributeConstraint: 'None'
      isSearchable: false
      inputHint: 'SingleLine'
      displayGroup: 'Other'
    })

    TestHelpers.setupProductType(@client, @productType, null, project_key)
    .then (result) =>
      @productType = result
      done()
    .catch (err) -> done.fail _.prettify(err.body)
  , 120000 # 2min

  describe '#import', ->

    beforeEach ->
      @newProductName = TestHelpers.uniqueId 'name-'
      @newProductSlug = TestHelpers.uniqueId 'slug-'
      @newProductSku = TestHelpers.uniqueId 'sku-'
      @newProductSku += '"foo"'

    it 'should fail because of a missing matchBy column', (done) ->
      csv =
        """
        productType,name,variantId,slug,key,variantKey
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},productKey,variantKey
        """
      @importer.matchBy = 'id'
      @importer.import(csv)
        .then () ->
          done.fail('Should throw an error')
        .catch (err) ->
          expect(err.toString()).toContain(
            "Error: CSV header does not contain matchBy \"id\" column.
            Use --matchBy to set different field for finding existing products."
          )
          done()

    it 'should transition a product state', (done) ->
      csv =
        """
        productType,name,slug,variantId,key,state
        #{@productType.id},#{@newProductName},#{@newProductSlug},1,productKey,previous-state
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
        """
        productType,name,slug,variantId,key,state
        #{@productType.id},#{@newProductName},#{@newProductSlug},1,productKey,next-state
        """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .expand 'state'
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.state.obj.key).toEqual 'next-state'
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should import a simple product, without setting state', (done) ->
      csv =
        """
        productType,name,variantId,slug,key,variantKey,state
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},productKey,variantKey,
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug
        expect(p.key).toEqual 'productKey'
        expect(p.state).toBeUndefined
        expect(p.masterVariant.key).toEqual 'variantKey'
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should import a simple product, without a state field in the csv', (done) ->
      csv =
        """
        productType,name,variantId,slug,key,variantKey
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},productKey,variantKey
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
          .where("productType(id=\"#{@productType.id}\")")
          .staged true
          .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug
        expect(p.key).toEqual 'productKey'
        expect(p.state).toBeUndefined
        expect(p.masterVariant.key).toEqual 'variantKey'
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should set state for a newly-created product when configured to do so', (done) ->
      csv =
        """
        productType,name,variantId,slug,key,variantKey,state
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},productKey,variantKey,
        """
      @importer = new Import {
        authConfig: authConfig
        httpConfig: httpConfig
        userAgentConfig: userAgentConfig
        defaultState: 'previous-state'
      }
      @importer.matchBy = 'sku'
      @importer.allowRemovalOfVariants = true
      @importer.suppressMissingHeaderWarning = true
      @client = @importer.client

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
          .where("productType(id=\"#{@productType.id}\")")
          .staged true
          .expand 'state'
          .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug
        expect(p.key).toEqual 'productKey'
        expect(p.state.obj.key).toEqual 'previous-state'
        expect(p.masterVariant.key).toEqual 'variantKey'
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should not fall over when the default state does not exist', (done) ->
      csv =
        """
        productType,name,variantId,slug,key,variantKey,state
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},productKey,variantKey,
        """
      @importer = new Import {
        authConfig: authConfig
        httpConfig: httpConfig
        userAgentConfig: userAgentConfig
        defaultState: 'nonexistent-state'
      }
      @importer.matchBy = 'sku'
      @importer.allowRemovalOfVariants = true
      @importer.suppressMissingHeaderWarning = true
      @client = @importer.client

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
          .where("productType(id=\"#{@productType.id}\")")
          .staged true
          .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug
        expect(p.key).toEqual 'productKey'
        expect(p.state).toBeUndefined
        expect(p.masterVariant.key).toEqual 'variantKey'
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should import a product with prices (even when one of them is discounted)', (done) ->
      csv =
        """
        productType,name,variantId,slug,prices
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},EUR 899;CH-EUR 999;DE-EUR 999|799;CH-USD 77777700 ##{CHANNEL_KEY}
        """

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(_.size p.masterVariant.prices).toBe 4
        prices = p.masterVariant.prices
        expect(prices[0].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 899)
        expect(prices[1].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 999)
        expect(prices[1].country).toBe 'CH'
        expect(prices[2].country).toBe 'DE'
        expect(prices[2].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 999)
        expect(prices[3].channel.typeId).toBe 'channel'
        expect(prices[3].channel.id).toBeDefined()
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should do nothing on 2nd import run', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},#{@newProductName},1,#{@newProductSlug}
        """
      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should update changes on 2nd import run', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},#{@newProductName},1,#{@newProductSlug}
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,key,variantKey
          #{@productType.id},#{@newProductName+'_changed'},1,#{@newProductSlug},productKey,variantKey
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: "#{@newProductName}_changed"
        expect(p.slug).toEqual en: @newProductSlug
        expect(p.key).toEqual 'productKey'
        expect(p.state).toBeUndefined
        expect(p.masterVariant.key).toEqual 'variantKey'

        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should import a product with prices and tiers', (done) ->
      csv =
        """
        productType,name,variantId,slug,prices
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},EUR 700%EUR 690 @1000%EUR 680 @3000
        """

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(_.size p.masterVariant.prices).toBe 1
        prices = p.masterVariant.prices
        expect(prices[0].value).toEqual jasmine.objectContaining(currencyCode: 'EUR', centAmount: 700)
        expect(prices[0].tiers.length).toEqual(2)
        expect(prices[0].tiers[0]).toEqual jasmine.objectContaining({minimumQuantity:1000, value: {type: 'centPrecision', fractionDigits: 2, currencyCode: 'EUR', centAmount: 690}})
        expect(prices[0].tiers[1]).toEqual jasmine.objectContaining({minimumQuantity:3000, value: {type: 'centPrecision', fractionDigits: 2, currencyCode: 'EUR', centAmount: 680}})
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should set default state on update when configured to do so, and product lacks state', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},#{@newProductName},1,#{@newProductSlug}
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
          .where("productType(id=\"#{@productType.id}\")")
          .staged true
          .expand 'state'
          .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.state).toBeUndefined

        csv =
          """
          productType,name,variantId,slug,key,variantKey
          #{@productType.id},#{@newProductName+'_changed'},1,#{@newProductSlug},productKey,variantKey
          """
        im = new Import {
          authConfig: authConfig
          httpConfig: httpConfig
          userAgentConfig: userAgentConfig
          defaultState: 'previous-state'
        }
        im.matchBy = 'slug'
        im.allowRemovalOfVariants = true
        im.suppressMissingHeaderWarning = true
        @client = im.client

        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
          .where("productType(id=\"#{@productType.id}\")")
          .staged true
          .expand 'state'
          .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: "#{@newProductName}_changed"
        expect(p.slug).toEqual en: @newProductSlug
        expect(p.key).toEqual 'productKey'
        expect(p.state.obj.key).toEqual 'previous-state'
        expect(p.masterVariant.key).toEqual 'variantKey'

        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should retain state on update when product lacks state in CSV but has it in CTP', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},#{@newProductName},1,#{@newProductSlug}
        """
      im = new Import {
        authConfig: authConfig
        httpConfig: httpConfig
        userAgentConfig: userAgentConfig
        defaultState: 'previous-state'
      }
      im.matchBy = 'slug'
      im.allowRemovalOfVariants = true
      im.suppressMissingHeaderWarning = true
      @client = im.client

      im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
          .where("productType(id=\"#{@productType.id}\")")
          .staged true
          .expand 'state'
          .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.state.obj.key).toEqual 'previous-state'

        csv =
          """
          productType,name,variantId,slug,key,variantKey
          #{@productType.id},#{@newProductName+'_changed'},1,#{@newProductSlug},productKey,variantKey
          """
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
          .where("productType(id=\"#{@productType.id}\")")
          .staged true
          .expand 'state'
          .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: "#{@newProductName}_changed"
        expect(p.slug).toEqual en: @newProductSlug
        expect(p.key).toEqual 'productKey'
        expect(p.state.obj.key).toEqual 'previous-state'
        expect(p.masterVariant.key).toEqual 'variantKey'

        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should handle all kind of attributes and constraints', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{TEXT_ATTRIBUTE_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL},#{REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE}
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},CU1,10,foo,uno;due,enum1
        ,,2,slug,CU2,20,foo,tre;quattro,enum2
        ,,3,slug,CU3,30,foo,cinque;sei,enum2,#{@productType.id}
        """
      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
          """
          productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{TEXT_ATTRIBUTE_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL},#{REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE},attribute.description.en,attribute.description.de
          #{@productType.id},#{@newProductName},1,#{@newProductSlug},CU1,10,bar,uno;due,enum2,,descAttrEn,descAttrDe
          ,,2,slug,CU2,10,bar,tre;quattro,enum2,#{@productType.id},descAttr1En,descAttr1De
          ,,3,slug,CU3,10,bar,cinque;sei,enum2,#{@productType.id},descAttr2En,descAttr2De
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.masterVariant.attributes[0]).toEqual {name: TEXT_ATTRIBUTE_NONE, value: 'bar'}
        expect(p.masterVariant.attributes[1]).toEqual {name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['uno', 'due']}
        expect(p.masterVariant.attributes[2]).toEqual {name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'CU1'}}
        expect(p.masterVariant.attributes[3]).toEqual {name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10}
        expect(p.masterVariant.attributes[4]).toEqual {name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}}
        # expect(p.masterVariant.attributes[5]).toEqual {name: 'description', value: { de: 'descAttrDe', en: 'descAttrEn' }}
        expect(p.masterVariant.attributes[6]).toBeUndefined()
        expect(p.variants[0].attributes[0]).toEqual {name: TEXT_ATTRIBUTE_NONE, value: 'bar'}
        expect(p.variants[0].attributes[1]).toEqual {name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['tre', 'quattro']}
        expect(p.variants[0].attributes[2]).toEqual {name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'CU2'}}
        expect(p.variants[0].attributes[3]).toEqual {name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10}
        expect(p.variants[0].attributes[4]).toEqual {name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}}
        expect(p.variants[0].attributes[5]).toEqual {name: REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE, value: {id: @productType.id, typeId: 'product-type'}}
        # expect(p.variants[0].attributes[6]).toEqual {name: 'description', value: { de: 'descAttr1De', en: 'descAttr1En' }}
        expect(p.variants[1].attributes[0]).toEqual {name: TEXT_ATTRIBUTE_NONE, value: 'bar'}
        expect(p.variants[1].attributes[1]).toEqual {name: REFERENCE_ATTRIBUTE_PRODUCT_TYPE_NONE, value: {id: @productType.id, typeId: 'product-type'}}
        expect(p.variants[1].attributes[2]).toEqual {name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['cinque', 'sei']}
        expect(p.variants[1].attributes[3]).toEqual {name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'CU3'}}
        expect(p.variants[1].attributes[4]).toEqual {name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10}
        expect(p.variants[1].attributes[5]).toEqual {name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}}
        # expect(p.variants[1].attributes[6]).toEqual {name: 'description', value: { de: 'descAttr2De', en: 'descAttr2En' }}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should handle multiple products', (done) ->
      p1 = TestHelpers.uniqueId 'name1-'
      p2 = TestHelpers.uniqueId 'name2-'
      p3 = TestHelpers.uniqueId 'name3-'
      s1 = TestHelpers.uniqueId 'slug1-'
      s2 = TestHelpers.uniqueId 'slug2-'
      s3 = TestHelpers.uniqueId 'slug3-'
      csv =
        """
        productType,name,variantId,slug,#{TEXT_ATTRIBUTE_NONE}
        #{@productType.id},#{p1},1,#{s1}
        ,,2,slug12,x
        #{@productType.id},#{p2},1,#{s2}
        #{@productType.id},#{p3},1,#{s3}
        """
      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 3
        expect(result[0]).toBe '[row 2] New product created.'
        expect(result[1]).toBe '[row 4] New product created.'
        expect(result[2]).toBe '[row 5] New product created.'
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 3
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        expect(result[1]).toBe '[row 4] Product update not necessary.'
        expect(result[2]).toBe '[row 5] Product update not necessary.'

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .sort("name.en")
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 3
        expect(result.body.results[0].name).toEqual {en: p1}
        expect(result.body.results[1].name).toEqual {en: p2}
        expect(result.body.results[2].name).toEqual {en: p3}
        expect(result.body.results[0].slug).toEqual {en: s1}
        expect(result.body.results[1].slug).toEqual {en: s2}
        expect(result.body.results[2].slug).toEqual {en: s3}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should handle set of enums', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{SET_ATTRIBUTE_ENUM_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE}
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},enum1;enum2,foo;bar,10
        ,,2,slug2,enum2,foo;bar;baz,20
        """
      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
          """
          productType,name,variantId,slug,#{SET_ATTRIBUTE_ENUM_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE}
          #{@productType.id},#{@newProductName},1,#{@newProductSlug},enum1,bar,100
          ,,2,slug2,enum2,foo,200
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.masterVariant.attributes[0]).toEqual {name: SET_ATTRIBUTE_ENUM_NONE, value: [{key: 'enum1', label: 'Enum1'}]}
        expect(p.masterVariant.attributes[1]).toEqual {name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['bar']}
        expect(p.masterVariant.attributes[2]).toEqual {name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 100}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should handle conflicting attribute names', (done) ->
      csv =
        """
        productType,name,variantId,sku,slug,attribute.productType
        #{@productType.id},#{@newProductName},1,sku1,#{@newProductSlug},newValue
        """

      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
          """
          productType,name,variantId,sku,slug,attribute.productType
          #{@productType.id},#{@newProductName},1,sku1,#{@newProductSlug},updatedValue
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.masterVariant.attributes[0]).toEqual {name: 'productType', value: 'updatedValue'}
        done()
      .catch (err) -> done.fail _.prettify(err)


    it 'should handle set of SameForAll enums with new variants', (done) ->
      csv =
        """
        productType,name,variantId,slug,sku,#{SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},#{TEXT_ATTRIBUTE_NONE},#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en
        #{@productType.id},#{@newProductSlug},1,#{@newProductSlug},#{@newProductSku},lenum1;lenum2,foo,fooEn
        """
      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
          """
          productType,name,variantId,slug,sku,#{SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},#{TEXT_ATTRIBUTE_NONE},#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en
          #{@productType.id},#{@newProductName},1,#{@newProductSlug},#{@newProductSku+1},lenum1;lenum2,foo,fooEn1
          ,,2,,#{@newProductSku+2},lenum1;lenum2,foo,fooEn2
          ,,3,,#{@newProductSku+3},lenum1;lenum2,foo,fooEn3
          ,,4,,#{@newProductSku+4},lenum1;lenum2,foo,fooEn4
          ,,5,,#{@newProductSku+5},lenum1;lenum2,foo,fooEn5
          ,,6,,#{@newProductSku+6},lenum1;lenum2,foo,fooEn6
          ,,7,,#{@newProductSku+7},lenum1;lenum2,foo,fooEn7
          ,,8,,#{@newProductSku+8},lenum1;lenum2,foo,fooEn8
          ,,9,,#{@newProductSku+9},lenum1;lenum2,foo,fooEn9
          ,,10,,#{@newProductSku+10},lenum1;lenum2,foo,fooEn10
          ,,11,,#{@newProductSku+11},lenum1;lenum2,foo,fooEn11
          ,,12,,#{@newProductSku+12},lenum1;lenum2,foo,fooEn12
          ,,13,,#{@newProductSku+13},lenum1;lenum2,foo,fooEn13
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.masterVariant.sku).toBe "#{@newProductSku}1"
        expect(p.masterVariant.attributes[0]).toEqual {name: TEXT_ATTRIBUTE_NONE, value: 'foo'}
        expect(p.masterVariant.attributes[1]).toEqual {name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'fooEn1'}}
        expect(p.masterVariant.attributes[2]).toEqual {name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum1', label: {en: 'Enum1'}}, {key: 'lenum2', label: {en: 'Enum2'}}]}
        _.each result.body.results[0].variants, (v, i) =>
          expect(v.sku).toBe "#{@newProductSku}#{i+2}"
          expect(v.attributes[0]).toEqual {name: TEXT_ATTRIBUTE_NONE, value: 'foo'}
          expect(v.attributes[1]).toEqual {name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: "fooEn#{i+2}"}}
          expect(v.attributes[2]).toEqual {name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum1', label: {en: 'Enum1'}}, {key: 'lenum2', label: {en: 'Enum2'}}]}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should remove a variant and change an SameForAll attribute at the same time', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
        #{@productType.id},#{@newProductSlug},1,#{@newProductSlug},foo,10,enum1
        ,,2,slug-2,bar,20,
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
          #{@productType.id},#{@newProductName},1,#{@newProductSlug},foo,10,enum1
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.variants).toEqual []
        expect(p.masterVariant.attributes[0]).toEqual {name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'foo'}}
        expect(p.masterVariant.attributes[1]).toEqual {name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10}
        expect(p.masterVariant.attributes[2]).toEqual {name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum1', label: 'Enum1'}}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should not removeVariant if allowRemovalOfVariants is off', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},foo,10,enum1
        ,,2,slug-2,bar,20,
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
          #{@productType.id},#{@newProductName},1,#{@newProductSlug},foo,10,enum1
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.allowRemovalOfVariants = false
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(_.size p.variants).toBe 1
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should execute SameForAll attribute change before addVariant', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},foo,10,enum1
        ,,2,slug-2,bar,20,
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
          #{@productType.id},#{@newProductName},1,#{@newProductSlug},foo,10,enum2
          ,,2,slug-2,bar,20,enum1
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual {en: @newProductName}
        expect(p.slug).toEqual {en: @newProductSlug}
        expect(p.masterVariant.attributes[0]).toEqual {name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'foo'}}
        expect(p.masterVariant.attributes[1]).toEqual {name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10}
        expect(p.masterVariant.attributes[2]).toEqual {name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}}
        expect(p.variants[0].attributes[0]).toEqual {name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'bar'}}
        expect(p.variants[0].attributes[1]).toEqual {name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 20}
        expect(p.variants[0].attributes[2]).toEqual {name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum2', label: 'Enum2'}}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should do a partial update of product base attributes', (done) ->
      csv =
        """
        productType,name.en,description.en,slug.en,variantId,searchKeywords.en,searchKeywords.fr
        #{@productType.id},#{@newProductName},foo bar,#{@newProductSlug},1,new;search;keywords,nouvelle;trouve
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,slug.en,variantId,searchKeywords.en,searchKeywords.fr
          #{@productType.id},#{@newProductSlug},1,new;search;keywords,nouvelle;trouve
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
          """
          productType,slug,name,variantId,sku,searchKeywords.de
          #{@productType.id},#{@newProductSlug},#{@newProductName+'_changed'},1,#{@newProductSku},neue;such;schlagwoerter
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual {en: "#{@newProductName}_changed"}
        expect(p.description).toEqual {en: 'foo bar'}
        expect(p.slug).toEqual {en: @newProductSlug}
        expect(p.masterVariant.sku).toBe @newProductSku
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should do a partial update of search keywords', (done) ->
      sku = cuid()
      product =
        name:
          en: @newProductName
        productType:
          id: @productType.id
          type: 'product-type'
        slug:
          en: @newProductSlug
        searchKeywords:
          en: [
            { text: "new" },
            { text: "search" },
            { text: "keywords" }
          ],
          fr: [
            { text: "nouvelle" },
            { text: "trouve" }
          ]
          de: [
            { text: "deutsche" },
            { text: "kartoffel" }
          ]
        masterVariant:
          sku: sku
      service = TestHelpers.createService(project_key, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: product
      }
      @client.execute request
      .then ({ body: { masterData: { current: { masterVariant } } } }) =>
        csv =
          """
          productType,variantId,sku,searchKeywords.en,searchKeywords.fr
          #{@productType.id},#{masterVariant.id},#{masterVariant.sku},newNew;search;keywords,nouvelleNew;trouveNew
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("name (en = \"#{@newProductName}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(result.body.results[0].searchKeywords).toEqual
          "en": [
            {
              "text": "newNew"
            },
            {
              "text": "search"
            },
            {
              "text": "keywords"
            }
          ],
          "fr": [
            {
              "text": "nouvelleNew"
            },
            {
              "text": "trouveNew"
            }
          ]
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should do a partial update of localized attributes', (done) ->
      csv =
        """
        productType,variantId,sku,name,description.en,description.de,description.fr,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.de,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.it
        #{@productType.id},1,#{@newProductSku},#{@newProductName},foo bar,bla bla,bon jour,english,german,italian
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku
          #{@productType.id},1,#{@newProductSku}
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
          """
          productType,variantId,sku,description.de,description.fr,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.it
          #{@productType.id},1,#{@newProductSku},"Hallo Welt",bon jour,english,ciao
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'

        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        # TODO: expecting 'foo bar'
        expect(p.description).toEqual jasmine.objectContaining {de: 'Hallo Welt', fr: 'bon jour'}
        # TODO: expecting {de: 'german'}
        expect(p.masterVariant.attributes[0]).toEqual jasmine.objectContaining {name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'english', it: 'ciao'}}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should do a partial update of custom attributes', (done) ->
      csv =
        """
        productType,name,slug,variantId,#{TEXT_ATTRIBUTE_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL},#{SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},sku
        #{@productType.id},#{@newProductName},#{@newProductSlug},1,hello,foo1;bar1,June,10,enum1,lenum1;lenum2,#{@newProductSku+1}
        ,,,2,hello,foo2;bar2,October,20,,,#{@newProductSku+2}
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku
          #{@productType.id},1,#{@newProductSku+1}
          ,2,#{@newProductSku+2}
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
        """
        productType,name,slug,variantId,#{SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},#{SET_ATTRIBUTE_TEXT_UNIQUE},sku
        #{@productType.id},#{@newProductName},#{@newProductSlug},1,lenum2,unique,#{@newProductSku+1}
        ,,,2,,still-unique,#{@newProductSku+2}
        """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(_.size p.variants).toBe 1
        expect(p.name).toEqual {en: @newProductName}
        expect(p.masterVariant.sku).toBe "#{@newProductSku}1"
        expect(p.masterVariant.attributes[0]).toEqual { name: TEXT_ATTRIBUTE_NONE, value: 'hello' }
        expect(p.masterVariant.attributes[1]).toEqual { name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['unique'] }
        expect(p.masterVariant.attributes[2]).toEqual { name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'June'} }
        expect(p.masterVariant.attributes[3]).toEqual { name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10 }
        expect(p.masterVariant.attributes[4]).toEqual { name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum1', label: 'Enum1'} }
        expect(p.masterVariant.attributes[5]).toEqual { name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum2', label: { en: 'Enum2' }}] }
        expect(p.variants[0].sku).toBe "#{@newProductSku}2"
        expect(p.variants[0].attributes[0]).toEqual { name: TEXT_ATTRIBUTE_NONE, value: 'hello' }
        expect(p.variants[0].attributes[1]).toEqual { name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['still-unique'] }
        expect(p.variants[0].attributes[2]).toEqual { name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'October'} }
        expect(p.variants[0].attributes[3]).toEqual { name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 20 }
        expect(p.variants[0].attributes[4]).toEqual { name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum1', label: 'Enum1'} }
        expect(p.variants[0].attributes[5]).toEqual { name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum2', label: { en: 'Enum2' }}] }
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'partial update should not overwrite name, prices and images', (done) ->
      csv =
        """
        productType,name,slug,variantId,prices,images
        #{@productType.id},#{@newProductName},#{@newProductSlug},1,EUR 999,//example.com/foo.jpg
        ,,,2,USD 70000,/example.com/bar.png
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,slug,variantId
          #{@productType.id},#{@newProductSlug},1
          ,,2
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual {en: @newProductName}
        expect(p.masterVariant.prices[0].value).toEqual jasmine.objectContaining(centAmount: 999, currencyCode: 'EUR')
        expect(p.masterVariant.images[0].url).toBe '//example.com/foo.jpg'
        expect(p.variants[0].prices[0].value).toEqual jasmine.objectContaining(centAmount: 70000, currencyCode: 'USD')
        expect(p.variants[0].images[0].url).toBe '/example.com/bar.png'
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should do a full update of SEO attribute', (done) ->
      csv =
        """
        productType,variantId,sku,name,metaTitle,metaDescription,metaKeywords
        #{@productType.id},1,#{@newProductSku},#{@newProductName},a,b,c
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku,name,metaTitle,metaDescription,metaKeywords
          #{@productType.id},1,#{@newProductSku},#{@newProductName},,b,changed
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual {en: @newProductName}
        expect(p.metaTitle).toEqual undefined
        expect(p.metaDescription).toEqual {en: 'b'}
        expect(p.metaKeywords).toEqual {en: 'changed'}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should do a full update of multi language SEO attribute', (done) ->
      csv =
        """
        productType,variantId,sku,name,metaTitle.de,metaDescription.de,metaKeywords.de,metaTitle.en,metaDescription.en,metaKeywords.en
        #{@productType.id},1,#{@newProductSku},#{@newProductName},metaTitleDe,metaDescDe,metaKeyDe,metaTitleEn,metaDescEn,metaKeyEn
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku,name,metaTitle.de,metaDescription.de,metaKeywords.de,metaTitle.en,metaDescription.en,metaKeywords.en
          #{@productType.id},1,#{@newProductSku},#{@newProductName},,newMetaDescDe,newMetaKeyDe,newMetaTitleEn,newMetaDescEn
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual {en: @newProductName}
        expect(p.metaTitle).toEqual {en: 'newMetaTitleEn'}
        expect(p.metaDescription).toEqual {en: 'newMetaDescEn', de: 'newMetaDescDe'}
        expect(p.metaKeywords).toEqual {de: 'newMetaKeyDe'}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should update SEO attribute if not all 3 headers are present', (done) ->
      csv =
        """
        productType,variantId,sku,name,metaTitle,metaDescription,metaKeywords
        #{@productType.id},1,#{@newProductSku},#{@newProductName},a,b,c
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku,name,metaTitle,metaDescription
          #{@productType.id},1,#{@newProductSku},#{@newProductName},x,y
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual {en: @newProductName}
        expect(p.metaTitle).toEqual {en: 'x'}
        expect(p.metaDescription).toEqual {en: 'y'}
        expect(p.metaKeywords).toEqual {en: 'c'}
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should do a partial update of prices based on SKUs', (done) ->
      csv =
      """
        productType,name,sku,variantId,prices
        #{@productType.id},#{@newProductName},#{@newProductSku+1},1,EUR 999
        ,,#{@newProductSku+2},2,USD 70000
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
        """
          sku,prices,productType
          #{@newProductSku+1},EUR 1999,#{@productType.name}
          #{@newProductSku+2},USD 80000,#{@productType.name}
          """
        im = createImporter()
        im.allowRemovalOfVariants = false
        im.updatesOnly = true
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual {en: @newProductName}
        expect(p.masterVariant.sku).toBe "#{@newProductSku}1"
        expect(p.masterVariant.prices[0].value).toEqual jasmine.objectContaining(centAmount: 1999, currencyCode: 'EUR')
        expect(p.variants[0].sku).toBe "#{@newProductSku}2"
        expect(p.variants[0].prices[0].value).toEqual jasmine.objectContaining(centAmount: 80000, currencyCode: 'USD')
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should import a simple product with different encoding', (done) ->
      encoding = "win1250"
      @importer.options.encoding = encoding
      @newProductName += "žýáíé"
      csv =
      """
        productType,name,variantId,slug
        #{@productType.id},#{@newProductName},1,#{@newProductSlug}
        """
      encoded = iconv.encode(csv, encoding)
      @importer.import(encoded)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should import a simple product file with different encoding', (done) ->
      encoding = "win1250"
      @importer.options.encoding = encoding
      @newProductName += "žýáíé"
      csv =
      """
        productType,name,variantId,slug
        #{@productType.id},#{@newProductName},1,#{@newProductSlug}
        """
      encoded = iconv.encode(csv, encoding)
      @importer.import(encoded)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should import a simple product file with different encoding using import manager', (done) ->
      filePath = "/tmp/test-import.csv"
      encoding = "win1250"
      @importer.options.encoding = encoding
      @newProductName += "žýáíé"
      csv =
      """
        productType,name,variantId,slug
        #{@productType.id},#{@newProductName},1,#{@newProductSlug}
        """
      encoded = iconv.encode(csv, encoding)
      fs.writeFileSync(filePath, encoded)

      @importer.importManager(filePath)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: @newProductName
        expect(p.slug).toEqual en: @newProductSlug
        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should update a product level info based only on SKU', (done) ->
      newProductNameUpdated = "#{@newProductName}-updated"
      categories = TestHelpers.generateCategories(4)

      csv =
      """
        productType,name,sku,variantId,prices,categories
        #{@productType.id},#{@newProductName},#{@newProductSku+1},1,EUR 999,1;2
        """

      TestHelpers.ensureCategories(@client, categories, project_key)
      .then =>
        @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        csv =
        """
          productType,sku,name.en,name.it,categories
          #{@productType.name},#{@newProductSku+1},#{newProductNameUpdated},#{newProductNameUpdated}-it,2;3
          """
        im = createImporter()
        im.allowRemovalOfVariants = false
        im.updatesOnly = true
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual {en: newProductNameUpdated, it: "#{newProductNameUpdated}-it"}
        expect(_.size(p.categories)).toEqual 2
        expect(p.masterVariant.sku).toBe "#{@newProductSku}1"
        expect(p.masterVariant.prices[0].value).toEqual jasmine.objectContaining(centAmount: 999, currencyCode: 'EUR')
        done()
      .catch (err) ->
        console.dir(err, {depth: 100})
        done.fail _.prettify(err)

    it 'should update a product level info and multiple variants based only on SKU', (done) ->
      updatedProductName = "#{@newProductName}-updated"
      skuPrefix = "sku-"

      csv =
      """
        productType,name,sku,variantId,prices
        #{@productType.id},#{@newProductName},#{skuPrefix+1},1,EUR 899
        ,,#{skuPrefix+3},2,EUR 899
        ,,#{skuPrefix+2},3,EUR 899
        ,,#{skuPrefix+4},4,EUR 899
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        csv =
        """
          productType,name,sku,prices
          #{@productType.id},#{updatedProductName},#{skuPrefix+1},EUR 100
          ,,#{skuPrefix+2},EUR 200
          ,,#{skuPrefix+3},EUR 300
          ,,#{skuPrefix+4},EUR 400
          """

        im = createImporter()
        im.allowRemovalOfVariants = false
        im.updatesOnly = true
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        p = result.body.results[0]

        getPrice = (variant) -> variant?.prices[0].value.centAmount
        getVariantBySku = (variants, sku) ->
          _.find variants, (v) -> v.sku == sku

        expect(p.name).toEqual {en: updatedProductName}
        expect(p.masterVariant.sku).toBe "#{skuPrefix}1"
        expect(getPrice(p.masterVariant)).toBe 100

        expect(_.size(p.variants)).toEqual 3
        expect(getPrice(getVariantBySku(p.variants, skuPrefix+2))).toBe 200
        expect(getPrice(getVariantBySku(p.variants, skuPrefix+3))).toBe 300
        expect(getPrice(getVariantBySku(p.variants, skuPrefix+4))).toBe 400

        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should update categories only when they are provided in import CSV', (done) ->
      skuPrefix = "sku-"
      csv =
      """
        productType,name,sku,variantId,categories
        #{@productType.id},#{@newProductName},#{skuPrefix}1,1,1;2
        """

      categories = TestHelpers.generateCategories(10)

      getImporter = ->
        im = createImporter()
        im.allowRemovalOfVariants = false
        im.updatesOnly = true
        im

      getCategoryByExternalId = (list, id) ->
        _.find list, (item) -> item.obj.externalId is String(id)

      TestHelpers.ensureCategories(@client, categories, project_key)
      .then =>
        @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        csv =
        """
          productType,sku
          #{@productType.id},#{skuPrefix+1}
          """

        getImporter().import(csv)
      .then (result) =>
        expect(result[0]).toBe '[row 2] Product update not necessary.'

        csv =
        """
          productType,sku,categories
          #{@productType.id},#{skuPrefix+1},3;4
          """

        getImporter().import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .expand("categories[*]")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        p = result.body.results[0]

        expect(p.name).toEqual {en: @newProductName}
        expect(p.masterVariant.sku).toBe "#{skuPrefix}1"

        expect(_.size(p.categories)).toEqual 2
        expect(!!getCategoryByExternalId(p.categories, 3)).toBe true
        expect(!!getCategoryByExternalId(p.categories, 4)).toBe true

        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should clear categories when an empty value given', (done) ->
      skuPrefix = "sku-"
      csv =
      """
        productType,name,sku,variantId,categories
        #{@productType.id},#{@newProductName},#{skuPrefix}1,1,1;2
        """

      categories = TestHelpers.generateCategories(4)

      getImporter = ->
        im = createImporter()
        im.allowRemovalOfVariants = false
        im.updatesOnly = true
        im

      TestHelpers.ensureCategories(@client, categories, project_key)
      .then =>
        @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'

        csv =
        """
          productType,sku,categories
          #{@productType.id},#{skuPrefix+1},
          """

        getImporter().import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        p = result.body.results[0]
        expect(_.size(p.categories)).toBe 0

        csv =
        """
          productType,sku,categories
          #{@productType.id},#{skuPrefix+1},3;4
          """

        getImporter().import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        p = result.body.results[0]
        expect(_.size(p.categories)).toBe 2

        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should handle a concurrent modification error when updating by SKU', (done) ->
      skuPrefix = "sku-"
      csv =
        """
        productType,name,sku,variantId,prices
        #{@productType.id},#{@newProductName},#{skuPrefix+1},1,EUR 100
        """
      for i in [2...41]
        csv += "\n,,#{skuPrefix+i},#{i},EUR 100"

      @importer.import(csv)
        .then =>
          service = TestHelpers.createService(project_key, 'productProjections')
          request = {
            uri: service
              .where("productType(id=\"#{@productType.id}\")")
              .staged true
              .build()
            method: 'GET'
          }
          @client.execute request
        .then (result) =>
          p = result.body.results[0]
          expect(p.variants.length).toEqual 39
          csv =
            """
            sku,productType,prices
            """

          for i in [1...41]
            csv += "\n#{skuPrefix+i},#{@productType.id},EUR 200"

          im = createImporter()
          im.allowRemovalOfVariants = false
          im.updatesOnly = true
          im.import csv
        .then =>
          service = TestHelpers.createService(project_key, 'productProjections')
          request = {
            uri: service
              .where("productType(id=\"#{@productType.id}\")")
              .staged true
              .build()
            method: 'GET'
          }
          @client.execute request
        .then (result) =>
          p = result.body.results[0]
          p.variants.push p.masterVariant

          p.variants.forEach (v) =>
            console.log v.sku, ":", v.prices[0].value.centAmount

          expect(p.variants.length).toEqual 40
          p.variants.forEach (variant) ->
            expect(variant.prices[0].value.centAmount).toEqual 200

          done()
        .catch (err) -> done.fail _.prettify(err)

    it 'should handle a concurrent modification error when updating by variantId', (done) ->
      skuPrefix = "sku-"

      csv =
        """
        productType,name,sku,variantId,prices
        """
      for i in [1...2]
        csv += "\n#{@productType.id},#{@newProductName+i},#{skuPrefix+i},1,EUR 100"

      @importer.import(csv)
      .then =>
        csv =
          """
          productType,name,sku,variantId,prices
          """
        for i in [1...5]
          csv += "\n#{@productType.id},#{@newProductName+i},#{skuPrefix}1,1,EUR 2#{i}"

        im = createImporter()
        im.allowRemovalOfVariants = false
        im.updatesOnly = true
        im.import csv
      .then ->
        # no concurrentModification found
        done()
      .catch (err) -> done.fail _.prettify(err)

    xit 'should split actions if there are more than 500 in actions array', (done) ->
      numberOfVariants = 501
      csvCreator = (productType, newProductName, newProductSlug, rows) ->
        changes = ""
        i = 0
        while i < rows
          changes += "#{productType.id},#{newProductName},#{1+i},#{newProductSlug},#{'productKey'+i},#{'variantKey'+i}\n"
          i++
        csv =
        """
        #{changes}
        """
        csv

      csv =
        """
        productType,name,variantId,slug,key,variantKey
        #{@productType.id},#{@newProductName},1,#{@newProductSlug},productKey0,variantKey0"
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,key,variantKey
          #{csvCreator(@productType, @newProductName, @newProductSlug, numberOfVariants)}
          """
        im = createImporter()
        im.matchBy = 'slug'
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        service = TestHelpers.createService(project_key, 'productProjections')
        request = {
          uri: service
            .where("productType(id=\"#{@productType.id}\")")
            .staged true
            .build()
          method: 'GET'
        }
        @client.execute request
      .then (result) =>
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0]
        expect(p.name).toEqual en: "#{@newProductName}"
        expect(p.slug).toEqual en: @newProductSlug
        expect(p.key).toEqual 'productKey0'
        expect(p.masterVariant.key).toEqual 'variantKey0'
        expect(p.variants.length).toBe numberOfVariants-1

        done()
      .catch (err) -> done.fail _.prettify(err)

    it 'should update product with multiple update requests', (done) ->
      client = @importer.client
      mockProduct = {
        key: 'mockProduct',
        name: {
          en: 'test product'
        },
        productType: {
          typeId: 'product-type',
          id: @productType.id
        },
        slug: {
          en: 'test-product'
        },
        description: {
          en: 'test description'
        },
        masterVariant: {
          sku: 'var1',
          key: 'var1'
        },
        variants: []
      }
      request = {
        uri: TestHelpers.createService(project_key, 'products').build()
        method: 'POST'
        body: mockProduct
      }

      client.execute(request)
        .then (res) =>
          mockUpdateRequests = [{
            version: null, ## will be taken from existing product
            actions: [{
              action: 'changeName',
              name: {
                en: 'updated name'
              }
            }]
          }, {
            version: null, ## will be taken from existing product
            actions: [{
              action: 'setDescription',
              description: {
                en: 'updated description'
              }
            }]
          }]
          @importer.updateProductInBatches(res.body, mockUpdateRequests)
        .then (res) =>
          expect(res.masterData.staged.name).toEqual({
            en: 'updated name'
          })
          expect(res.masterData.staged.description).toEqual({
            en: 'updated description'
          })
          done()
        .catch (err) -> done.fail _.prettify(err)
