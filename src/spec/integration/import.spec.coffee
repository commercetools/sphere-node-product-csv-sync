_ = require 'underscore'
Import = require '../../lib/import'
Config = require '../../config'
TestHelpers = require './testhelpers'

jasmine.getEnv().defaultTimeoutInterval = 60000

createImporter = ->
  im = new Import Config
  im.allowRemovalOfVariants = true
  im

describe 'Import', ->
  beforeEach (done) ->
    @importer = createImporter()
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

    @productType =
      name: 'myType'
      description: 'foobar'
      attributes: [
        { name: 'descN', label: { de: 'descN' }, type: { name: 'ltext'}, attributeConstraint: 'None', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descU', label: { de: 'descU' }, type: { name: 'text'}, attributeConstraint: 'Unique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descCU1', label: { de: 'descCU1' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descCU2', label: { de: 'descCU2' }, type: { name: 'text'}, attributeConstraint: 'CombinationUnique', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'descS', label: { de: 'descS' }, type: { name: 'text'}, attributeConstraint: 'SameForAll', isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
        { name: 'multiEnum', label: { de: 'multiEnum' }, type: { name: 'set', elementType: { name: 'enum', values: values } }, attributeConstraint: 'None', isRequired: false, isSearchable: false }
        { name: 'multiSamelEnum', label: { de: 'multiSamelEnum' }, type: { name: 'set', elementType: { name: 'lenum', values: lvalues } }, attributeConstraint: 'SameForAll', isRequired: false, isSearchable: false }
      ]

    TestHelpers.setup(@client, @productType).then (result) =>
      @productType = result
      done()
    .fail (err) ->
      done(_.prettify err)
    .done()


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
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should import a product with prices', (done) ->
      csv =
        """
        productType,name,variantId,slug,prices
        #{@productType.id},myProduct,1,slug,EUR 899;CH-EUR 999;CH-USD 77777700 #retailerA
        """
      @importer.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        done()
      .fail (err) ->
        done(_.prettify err)
      .done()

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
      .fail (err) ->
        done(_.prettify err)
      .done()

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
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should handle all kind of attributes and constraints', (done) ->
      csv =
        """
        productType,name,variantId,slug,descN,descU,descUC1,descUC2,descS
        #{@productType.id},myProduct1,1,slugi,,text1,foo,bar,same
        ,,2,slug,free,text2,foo,baz,same
        ,,3,slug,,text3,boo,baz,sameDifferentWhichWillBeIgnoredAsItIsDefined
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
          productType,name,variantId,slug,descN,descU,descCU1,descCU2,descS
          #{@productType.id},myProduct1,1,slugi,,text4,boo,bar,STILL_SAME
          ,,2,slug,free,text2,foo,baz,STILL_SAME
          ,,3,slug,CHANGED,text3,boo,baz,STILL_SAME
          """
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        done()
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should handle multiple products', (done) ->
      csv =
        """
        productType,name,variantId,slug,descU,descCU1
        #{@productType.id},myProduct1,1,slug1
        ,,2,slug12,x,y
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
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should handle set of enums', (done) ->
      csv =
        """
        productType,name,variantId,slug,multiEnum,descU,descCU1
        #{@productType.id},myProduct1,1,slug1,y;x,a,b
        ,,2,slug2,x;z,b,a
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
          productType,name,variantId,slug,multiEnum,descU,descCU1
          #{@productType.id},myProduct1,1,slug1,y;x;z,a,b
          ,,2,slug2,z,b,a
          """
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        done()
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should handle set of SameForAll enums with new variants', (done) ->
      csv =
        """
        productType,name,variantId,slug,sku,multiSamelEnum,descU,descCU1
        #{@productType.id},myProduct1,1,slug1,sku1,aa;bb;cc,a,b
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
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        done()
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should remove a variant and change an SameForAll attribute at the same time', (done) ->
      csv =
        """
        productType,name,variantId,slug,descU,descCU1,descS
        #{@productType.id},myProduct-1,1,slug-1,a,b,SAMESAME
        ,,2,slug-2,b,a,
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,descU,descCU1,descS
          #{@productType.id},myProduct-1,1,slug-1,a,b,SAMESAME_BUTDIFFERENT
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
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should not removeVariant if allowRemovalOfVariants is off', (done) ->
      csv =
        """
        productType,name,variantId,slug,descU,descCU1
        #{@productType.id},myProduct-1,1,slug-1,a,b
        ,,2,slug-2,b,a,
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,descU,descCU1
          #{@productType.id},myProduct-1,1,slug-1,a,b
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
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should execute SameForAll attribute change before addVariant', (done) ->
      csv =
        """
        productType,name,variantId,slug,descU,descCU1,descS
        #{@productType.id},myProduct-1,1,slug-1,a,b,SAMESAME
        """
      @importer.import(csv)
      .then (result) =>
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] New product created.'
        csv =
          """
          productType,name,variantId,slug,descU,descCU1,descS
          #{@productType.id},myProduct-1,1,slug-1,a,b,SAMESAME_BUTDIFFERENT
          ,,2,slug-2,b,a,WE_WILL_IGNORE_THIS
          """
        im = createImporter()
        im.import(csv)
      .then (result) ->
        expect(_.size result).toBe 1
        expect(result[0]).toBe '[row 2] Product updated.'
        done()
      .fail (err) ->
        done(_.prettify err)
      .done()

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
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should do a partial update of localized attributes', (done) ->
      csv =
        """
        productType,variantId,sku,name,description.en,description.de,descN.en,descN.de,descN.it
        #{@productType.id},1,someSKU,myProductY,foo bar,bla bla,english,german,italian
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
          productType,variantId,sku,description.de,descN.it
          #{@productType.id},1,someSKU,"Hallo Welt",ciao
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
          a.name = 'descN'
        expect(attrib.value.en).toBeUndefined() # TODO: expecting 'english'
        expect(attrib.value.de).toBeUndefined() # TODO: expecting 'german'
        expect(attrib.value.it).toBe 'ciao'
        done()
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should do a partial update of custom attributes', (done) ->
      csv =
        """
        productType,name,slug,variantId,descN,descU,descCU1,descCU2,descS,multiEnum,multiSamelEnum,sku
        #{@productType.id},x,my-slug,1,a,b,c,d,S,x,aa;bb,myPersonalSKU1
        ,,,2,b,c,d,e,S,x;y;z,,myPersonalSKU2
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
        productType,name,slug,variantId,multiSamelEnum,sku
        #{@productType.id},x,my-slug,1,cc,myPersonalSKU3
        ,,,2,,myPersonalSKU2
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
        expect(ats[0]).toEqual { name: 'descN', value: { en: 'a' } }
        expect(ats[1]).toEqual { name: 'descU', value: 'b' }
        expect(ats[2]).toEqual { name: 'descCU1', value: 'c' }
        expect(ats[3]).toEqual { name: 'descCU2', value: 'd' }
        expect(ats[4]).toEqual { name: 'descS', value: 'S' }
        expect(ats[5]).toEqual { name: 'multiEnum', value: [{ key: 'x', label: 'X' }] }
        expect(ats[6]).toEqual { name: 'multiSamelEnum', value: [{ key: 'cc', label: { en: 'CC', 'de': 'Cc' } }] }
        ats = p.variants[0].attributes
        expect(ats[0]).toEqual { name: 'descN', value: { en: 'b' } }
        expect(ats[1]).toEqual { name: 'descU', value: 'c' }
        expect(ats[2]).toEqual { name: 'descCU1', value: 'd' }
        expect(ats[3]).toEqual { name: 'descCU2', value: 'e' }
        expect(ats[4]).toEqual { name: 'descS', value: 'S' }
        expect(ats[5]).toEqual { name: 'multiEnum', value: [{ key: 'x', label: 'X' }, { key: 'y', label: 'Y' }, { key: 'z', label: 'Z' }] }
        expect(ats[6]).toEqual { name: 'multiSamelEnum', value: [{ key: 'cc', label: { en: 'CC', 'de': 'Cc' } }] }
        done()
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should do a partial update of prices and images', (done) ->
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
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should do a full update of SEO attribute', (done) ->
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
      .fail (err) ->
        done(_.prettify err)
      .done()

    it 'should not update SEO attribute if not all 3 headers are present', (done) ->
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
      .fail (err) ->
        done(_.prettify err)
      .done()
