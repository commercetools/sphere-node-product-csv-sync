_ = require 'underscore'
_.mixin require('underscore-mixins')
{Import} = require '../../lib/main'
Config = require '../../config'
TestHelpers = require './testhelpers'

TEXT_ATTRIBUTE_NONE = 'attr-text-n'
LTEXT_ATTRIBUTE_COMBINATION_UNIQUE = 'attr-ltext-cu'
NUMBER_ATTRIBUTE_COMBINATION_UNIQUE = 'attr-number-cu'
ENUM_ATTRIBUTE_SAME_FOR_ALL = 'attr-enum-sfa'
SET_ATTRIBUTE_TEXT_UNIQUE = 'attr-set-text-u'
SET_ATTRIBUTE_ENUM_NONE = 'attr-set-enum-u'
SET_ATTRIBUTE_LENUM_SAME_FOR_ALL = 'attr-set-lenum-sfa'

createImporter = ->
  im = new Import Config
  im.allowRemovalOfVariants = true
  im.validator.suppressMissingHeaderWarning = true
  im

describe 'Import integration test', ->

  beforeEach (done) ->
    @importer = createImporter()
    @importer.validator.suppressMissingHeaderWarning = true
    @client = @importer.client

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

    @productType = TestHelpers.mockProductType()
      # name: 'myImportType'
      # description: 'foobar'
      # attributes: [
      #   { name: 'descN', label: { de: 'descN' }, type: { name: 'ltext'}, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
      #   { name: 'descU', label: { de: 'descU' }, type: { name: 'text'}, attributeConstraint: 'Unique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
      #   { name: 'descCU1', label: { de: 'descCU1' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
      #   { name: 'descCU2', label: { de: 'descCU2' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
      #   { name: 'descS', label: { de: 'descS' }, type: { name: 'text'}, attributeConstraint: 'SameForAll', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
      #   { name: 'multiEnum', label: { de: 'multiEnum' }, type: { name: 'set', elementType: { name: 'enum', values: values } }, attributeConstraint: 'None', isRequired: false, isSearchable: false }
      #   { name: 'multiSamelEnum', label: { de: 'multiSamelEnum' }, type: { name: 'set', elementType: { name: 'lenum', values: lvalues } }, attributeConstraint: 'SameForAll', isRequired: false, isSearchable: false }
      # ]

    TestHelpers.setupProductType(@client, @productType)
    .then (result) =>
      @productType = result
      @client.channels.ensure('retailerA', 'InventorySupply')
    .then -> done()
    .catch (err) -> done _.prettify(err)
    .done()
  , 50000 # 50sec

  describe '#import', ->

    it 'should import a simple product', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},myProduct,1,slug
        """
      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should import a product with prices', (done) ->
      csv =
        """
        productType,name,variantId,slug,prices
        #{@productType.id},myProduct,1,slug,EUR 899;CH-EUR 999;CH-USD 77777700 #retailerA
        """

      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(_.size p.masterVariant.prices).toBe 3
        prices = p.masterVariant.prices
        expect(prices[0].value).toEqual { currencyCode: 'EUR', centAmount: 899 }
        expect(prices[1].value).toEqual { currencyCode: 'EUR', centAmount: 999 }
        expect(prices[1].country).toBe 'CH'
        expect(prices[2].channel.typeId).toBe 'channel'
        expect(prices[2].channel.id).toBeDefined()
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should do nothing on 2nd import run', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},myProduct1,1,slug
        """
      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should update changes on 2nd import run', (done) ->
      csv =
        """
        productType,name,variantId,slug
        #{@productType.id},myProductX,1,sluguniqe
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug
          #{@productType.id},CHANGED,1,sluguniqe
          """
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should handle all kind of attributes and constraints', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{TEXT_ATTRIBUTE_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
        #{@productType.id},myProduct1,1,slugi,CU1,10,foo,uno;due,enum1
        ,,2,slug,CU2,20,foo,tre;quattro,enum2
        ,,3,slug,CU3,30,foo,cinque;sei,enum2
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
          productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{TEXT_ATTRIBUTE_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
          #{@productType.id},myProduct1,1,slugi,CU1,10,bar,uno;due,enum2
          ,,2,slug,CU2,10,bar,tre;quattro,enum2
          ,,3,slug,CU3,10,bar,cinque;sei,enum2
          """
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should handle multiple products', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{TEXT_ATTRIBUTE_NONE}
        #{@productType.id},myProduct1,1,slug1
        ,,2,slug12,x
        #{@productType.id},myProduct2,1,slug2
        #{@productType.id},myProduct3,1,slug3
        """
      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 3
        expect(result[0]).toBe '[row 2] New product created.'
        expect(result[1]).toBe '[row 4] New product created.'
        expect(result[2]).toBe '[row 5] New product created.'
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 3
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        expect(result[1]).toBe '[row 4] Product update not necessary.'
        expect(result[2]).toBe '[row 5] Product update not necessary.'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should handle set of enums', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{SET_ATTRIBUTE_ENUM_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE}
        #{@productType.id},myProduct1,1,slug1,enum1;enum2,foo;bar,10
        ,,2,slug2,enum2,foo;bar;baz,20
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
          productType,name,variantId,slug,#{SET_ATTRIBUTE_ENUM_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE}
          #{@productType.id},myProduct1,1,slug1,enum1,bar,100
          ,,2,slug2,enum2,foo,200
          """
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should handle set of SameForAll enums with new variants', (done) ->
      csv =
        """
        productType,name,variantId,slug,sku,#{SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},#{TEXT_ATTRIBUTE_NONE},#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en
        #{@productType.id},myProduct1,1,slug1,sku1,lenum1;lenum2,foo,fooEn
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
          #{@productType.id},myProduct1,1,slug1,sku1,lenum1;lenum2,foo,fooEn1
          ,,2,slug2,sku2,lenum1;lenum2,foo,fooEn2
          ,,3,slug3,sku3,lenum1;lenum2,foo,fooEn3
          ,,4,slug4,sku4,lenum1;lenum2,foo,fooEn4
          ,,5,slug5,sku5,lenum1;lenum2,foo,fooEn5
          ,,6,slug6,sku6,lenum1;lenum2,foo,fooEn6
          ,,7,slug7,sku7,lenum1;lenum2,foo,fooEn7
          ,,8,slug8,sku8,lenum1;lenum2,foo,fooEn8
          ,,9,slug9,sku9,lenum1;lenum2,foo,fooEn9
          ,,10,slug10,sku10,lenum1;lenum2,foo,fooEn10
          ,,11,slug11,sku11,lenum1;lenum2,foo,fooEn11
          ,,12,slug12,sku12,lenum1;lenum2,foo,fooEn12
          ,,13,slug13,sku13,lenum1;lenum2,foo,fooEn13
          """
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should remove a variant and change an SameForAll attribute at the same time', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
        #{@productType.id},myProduct-1,1,slug-1,foo,10,enum1
        ,,2,slug-2,bar,20,
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
          #{@productType.id},myProduct-1,1,slug-1,foo,10,enum1
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(_.size p.variants).toBe 0
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should not removeVariant if allowRemovalOfVariants is off', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
        #{@productType.id},myProduct-1,1,slug-1,foo,10,enum1
        ,,2,slug-2,bar,20,
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
          #{@productType.id},myProduct-1,1,slug-1,foo,10,enum1
          """
        im = createImporter()
        im.allowRemovalOfVariants = false
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(_.size p.variants).toBe 1
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should execute SameForAll attribute change before addVariant', (done) ->
      csv =
        """
        productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
        #{@productType.id},myProduct-1,1,slug-1,foo,10,enum1
        ,,2,slug-2,bar,20,
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL}
          #{@productType.id},myProduct-1,1,slug-1,foo,10,enum2
          ,,2,slug-2,bar,20,enum1
          """
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should do a partial update of product base attributes', (done) ->
      csv =
        """
        productType,name.en,description.en,slug.en,variantId
        #{@productType.id},myProductX,foo bar,my-product-x,1
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,slug.en,variantId
          #{@productType.id},my-product-x,1
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
          """
          productType,slug,name,variantId,sku
          #{@productType.id},my-product-x,XYZ,1,foo
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(p.name.en).toBe 'XYZ'
        expect(p.description.en).toBe 'foo bar'
        expect(p.slug.en).toBe 'my-product-x'
        expect(p.masterVariant.sku).toBe 'foo'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should do a partial update of localized attributes', (done) ->
      csv =
        """
        productType,variantId,sku,name,description.en,description.de,description.fr,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.de,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.it
        #{@productType.id},1,someSKU,myProductY,foo bar,bla bla,bon jour,english,german,italian
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku
          #{@productType.id},1,someSKU
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
          """
          productType,variantId,sku,description.de,description.fr,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.it
          #{@productType.id},1,someSKU,"Hallo Welt",bon jour,english,ciao
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(p.description.en).toBeUndefined() # TODO: expecting 'foo bar'
        expect(p.description.de).toBe 'Hallo Welt'
        attrib = _.find p.masterVariant.attributes, (a) ->
          a.name = LTEXT_ATTRIBUTE_COMBINATION_UNIQUE
        expect(attrib.value.en).toBe 'english'
        expect(attrib.value.de).toBeUndefined() # TODO: expecting 'german'
        expect(attrib.value.it).toBe 'ciao'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    it 'should do a partial update of custom attributes', (done) ->
      csv =
        """
        productType,name,slug,variantId,#{TEXT_ATTRIBUTE_NONE},#{SET_ATTRIBUTE_TEXT_UNIQUE},#{LTEXT_ATTRIBUTE_COMBINATION_UNIQUE}.en,#{NUMBER_ATTRIBUTE_COMBINATION_UNIQUE},#{ENUM_ATTRIBUTE_SAME_FOR_ALL},#{SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},sku
        #{@productType.id},x,my-slug,1,hello,foo1;bar1,June,10,enum1,lenum1;lenum2,myPersonalSKU1
        ,,,2,hello,foo2;bar2,October,20,,,myPersonalSKU2
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku
          #{@productType.id},1,myPersonalSKU1
          ,2,myPersonalSKU2
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        csv =
        """
        productType,name,slug,variantId,#{SET_ATTRIBUTE_LENUM_SAME_FOR_ALL},#{SET_ATTRIBUTE_TEXT_UNIQUE},sku
        #{@productType.id},x,my-slug,1,lenum2,unique,myPersonalSKU3
        ,,,2,,still-unique,myPersonalSKU2
        """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(_.size p.variants).toBe 1
        expect(p.name.en).toBe 'x'
        expect(p.masterVariant.sku).toBe 'myPersonalSKU3'
        expect(p.variants[0].sku).toBe 'myPersonalSKU2'
        ats = p.masterVariant.attributes
        expect(ats[0]).toEqual { name: TEXT_ATTRIBUTE_NONE, value: 'hello' }
        expect(ats[1]).toEqual { name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['unique'] }
        expect(ats[2]).toEqual { name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'June'} }
        expect(ats[3]).toEqual { name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 10 }
        expect(ats[4]).toEqual { name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum1', label: 'Enum1'} }
        expect(ats[5]).toEqual { name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum2', label: { en : 'Enum2' }}] }
        ats = p.variants[0].attributes
        expect(ats[0]).toEqual { name: TEXT_ATTRIBUTE_NONE, value: 'hello' }
        expect(ats[1]).toEqual { name: SET_ATTRIBUTE_TEXT_UNIQUE, value: ['still-unique'] }
        expect(ats[2]).toEqual { name: LTEXT_ATTRIBUTE_COMBINATION_UNIQUE, value: {en: 'October'} }
        expect(ats[3]).toEqual { name: NUMBER_ATTRIBUTE_COMBINATION_UNIQUE, value: 20 }
        expect(ats[4]).toEqual { name: ENUM_ATTRIBUTE_SAME_FOR_ALL, value: {key: 'enum1', label: 'Enum1'} }
        expect(ats[5]).toEqual { name: SET_ATTRIBUTE_LENUM_SAME_FOR_ALL, value: [{key: 'lenum2', label: { en : 'Enum2' }}] }
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    xit 'partial update should not overwrite name, prices and images', (done) ->
      csv =
        """
        productType,name,slug,variantId,prices,images
        #{@productType.id},y,my-slug,1,EUR 999,//example.com/foo.jpg
        ,,,2,USD 70000,/example.com/bar.png
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,slug,variantId
          #{@productType.id},my-slug,1
          ,,2
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(p.name.en).toBe 'y'
        expect(p.masterVariant.prices[0].value).toEqual { centAmount: 999, currencyCode: 'EUR' }
        expect(p.variants[0].prices[0].value).toEqual { centAmount: 70000, currencyCode: 'USD' }
        expect(p.masterVariant.images[0].url).toBe '//example.com/foo.jpg'
        expect(p.variants[0].images[0].url).toBe '/example.com/bar.png'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    xit 'should do a full update of SEO attribute', (done) ->
      csv =
        """
        productType,variantId,sku,name,metaTitle,metaDescription,metaKeywords
        #{@productType.id},1,a111,mySeoProdcut,a,b,c
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku,name,metaTitle,metaDescription,metaKeywords
          #{@productType.id},1,a111,mySeoProdcut,,b,changed
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(p.name.en).toBe 'mySeoProdcut'
        expect(p.metaTitle.en).toBe 'a' # I would actually expect ''
        expect(p.metaDescription.en).toBe 'b'
        expect(p.metaKeywords.en).toBe 'changed'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    xit 'should do a full update of multi language SEO attribute', (done) ->
      csv =
        """
        productType,variantId,sku,name,metaTitle.de,metaDescription.de,metaKeywords.de,metaTitle.en,metaDescription.en,metaKeywords.en
        #{@productType.id},1,a111,mySeoProduct,metaTitleDe,metaDescDe,metaKeyDe,metaTitleEn,metaDescEn,metaKeyEn
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku,name,metaTitle.de,metaDescription.de,metaKeywords.de,metaTitle.en,metaDescription.en,metaKeywords.en
          #{@productType.id},1,a111,mySeoProduct,,newMetaDescDe,newMetaKeyDe,newMetaTitleEn,newMetaDescEn
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(p.name.en).toBe 'mySeoProduct'
        expect(p.metaTitle.de).not.toBeDefined()
        expect(p.metaDescription.de).toBe 'newMetaDescDe'
        expect(p.metaKeywords.de).toBe 'newMetaKeyDe'
        expect(p.metaTitle.en).toBe 'newMetaTitleEn'
        expect(p.metaDescription.en).toBe 'newMetaDescEn'
        expect(p.metaKeywords.en).not.toBeDefined()
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec


    xit 'should not update SEO attribute if not all 3 headers are present', (done) ->
      csv =
        """
        productType,variantId,sku,name,metaTitle,metaDescription,metaKeywords
        #{@productType.id},1,a111,mySeoProdcut,a,b,c
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,variantId,sku,name,metaTitle,metaDescription
          #{@productType.id},1,a111,mySeoProdcut,x,y
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product update not necessary.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(p.name.en).toBe 'mySeoProdcut'
        expect(p.metaTitle.en).toBe 'a'
        expect(p.metaDescription.en).toBe 'b'
        expect(p.metaKeywords.en).toBe 'c'
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec

    xit 'should do a partial update of prices based on SKUs', (done) ->
      csv =
        """
        productType,name,sku,variantId,prices
        #{@productType.id},xyz,sku1,1,EUR 999
        ,,sku2,2,USD 70000
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          variantId,sku,prices,productType
          1,sku1,EUR 1999,#{@productType.name}
          2,sku2,USD 80000
          """
        im = createImporter()
        im.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        @client.products.where("productType(id=\"#{@productType.id}\")").fetch()
      .then (result) ->
        expect(_.size result.body.results).toBe 1
        p = result.body.results[0].masterData.staged
        expect(p.name.en).toBe 'xyz'
        expect(p.masterVariant.sku).toBe 'sku1'
        expect(p.masterVariant.prices[0].value).toEqual { centAmount: 1999, currencyCode: 'EUR' }
        expect(p.variants[0].sku).toBe 'sku2'
        expect(p.variants[0].prices[0].value).toEqual { centAmount: 80000, currencyCode: 'USD' }
        done()
      .catch (err) -> done _.prettify(err)
      .done()
    , 50000 # 50sec
