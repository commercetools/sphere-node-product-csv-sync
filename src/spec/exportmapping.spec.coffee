_ = require('underscore')._
ExportMapping = require '../lib/exportmapping'
Header = require '../lib/header'
Types = require '../lib/types'
CONS = require '../lib/constants'

describe 'ExportMapping', ->
  beforeEach ->
    @exportMapping = new ExportMapping()

  describe '#constructor', ->
    it 'should initialize', ->
      expect(@exportMapping).toBeDefined()

  describe '#mapPrices', ->
    beforeEach ->
      @exportMapping.channelService =
        id2key: {}
      @exportMapping.customerGroupService =
        id2name: {}
    it 'should map simple price', ->
      prices = [
        { value: { centAmount: 999, currencyCode: 'EUR' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR 999'

    it 'should map price with country', ->
      prices = [
        { value: { centAmount: 77, currencyCode: 'EUR' }, country: 'DE' }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'DE-EUR 77'

    it 'should map multiple prices', ->
      prices = [
        { value: { centAmount: 999, currencyCode: 'EUR' } }
        { value: { centAmount: 1099, currencyCode: 'USD' } }
        { value: { centAmount: 1299, currencyCode: 'CHF' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR 999;USD 1099;CHF 1299'

    it 'should map channel on price', ->
      @exportMapping.channelService.id2key['c123'] = 'myKey'
      prices = [
        { value: { centAmount: 999, currencyCode: 'EUR' }, channel: { id: 'c123' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR 999#myKey'

    it 'should map customerGroup on price', ->
      @exportMapping.customerGroupService.id2name['cg987'] = 'B2B'
      prices = [
        { value: { centAmount: 9999999, currencyCode: 'USD' }, customerGroup: { id: 'cg987' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'USD 9999999 B2B'

    it 'should map customerGroup and channel on price', ->
      @exportMapping.channelService.id2key['channel_123'] = 'WAREHOUSE-1'
      @exportMapping.customerGroupService.id2name['987-xyz'] = 'sales'
      prices = [
        { value: { centAmount: -13, currencyCode: 'EUR' }, customerGroup: { id: '987-xyz' }, channel: { id: 'channel_123' } }
      ]
      expect(@exportMapping._mapPrices prices).toBe 'EUR -13 sales#WAREHOUSE-1'


  describe '#mapImage', ->
    it 'should map single image', ->
      images = [
        { url: '//example.com/image.jpg' }
      ]
      expect(@exportMapping._mapImages images).toBe '//example.com/image.jpg'

    it 'should map multiple images', ->
      images = [
        { url: '//example.com/image.jpg' }
        { url: 'https://www.example.com/pic.png' }
      ]
      expect(@exportMapping._mapImages images).toBe '//example.com/image.jpg;https://www.example.com/pic.png'


  describe '#mapAttribute', ->
    beforeEach ->
      @exportMapping.typesService = new Types()
      @productType =
        id: '123'
        attributes: [
          { name: 'myTextAttrib', type: { name: 'text' } }
          { name: 'myEnumAttrib', type: { name: 'enum' } }
          { name: 'myTextSetAttrib', type: { name: 'set', elementType: { name: 'text' } } }
          { name: 'myEnumSetAttrib', type: { name: 'set', elementType: { name: 'lenum' } } }
        ]
      @exportMapping.typesService.buildMaps [@productType]

    it 'should map simple attribute', ->
      attribute =
        name: 'myTextAttrib'
        value: 'some text'
      expect(@exportMapping._mapAttribute attribute, @productType.attributes[0].type).toBe 'some text'

    it 'should map enum attribute', ->
      attribute =
        name: 'myEnumAttrib'
        value:
          label:
            en: 'bla'
          key: 'myEnum'
      expect(@exportMapping._mapAttribute attribute, @productType.attributes[1].type).toBe 'myEnum'

    it 'should map text set attribute', ->
      attribute =
        name: 'myTextSetAttrib'
        value: [ 'x', 'y', 'z' ]
      expect(@exportMapping._mapAttribute attribute, @productType.attributes[2].type).toBe 'x;y;z'

    it 'should map enum set attribute', ->
      attribute =
        name: 'foo'
        value: [
          { label:
              en: 'bla'
            key: 'myEnum' }
          { label:
              en: 'foo'
            key: 'myEnum2' }
        ]
      expect(@exportMapping._mapAttribute attribute, @productType.attributes[3].type).toBe 'myEnum;myEnum2'

  describe '#mapVariant', ->
    it 'should map variant id and sku', ->
      @exportMapping.header = new Header([CONS.HEADER_VARIANT_ID, CONS.HEADER_SKU])
      @exportMapping.header.toIndex()
      variant =
        id: '12'
        sku: 'mySKU'
        attributes: []
      row = @exportMapping._mapVariant(variant)
      expect(row).toEqual [ '12', 'mySKU' ]

    it 'should map variant attributes', ->
      @exportMapping.header = new Header([ 'foo' ])
      @exportMapping.header.toIndex()
      @exportMapping.typesService = new Types()
      productType =
        id: '123'
        attributes: [
          { name: 'foo', type: { name: 'text' } }
        ]
      @exportMapping.typesService.buildMaps [productType]
      variant =
        attributes: [
          { name: 'foo', value: 'bar' }
        ]
      row = @exportMapping._mapVariant(variant, productType)
      expect(row).toEqual [ 'bar' ]

  describe '#mapBaseProduct', ->
    it 'should map productType (name) and product id', ->
      @exportMapping.header = new Header([CONS.HEADER_PRODUCT_TYPE,CONS.HEADER_ID])
      @exportMapping.header.toIndex()
      product =
        id: '123'
        masterVariant:
          attributes: []
      type =
        name: 'myType'
        id: 'typeId123'
      row = @exportMapping._mapBaseProduct(product, type)
      expect(row).toEqual [ 'myType', '123' ]

    it 'should map tax category name', ->
      @exportMapping.header = new Header([CONS.HEADER_TAX])
      @exportMapping.header.toIndex()
      @exportMapping.taxService =
        id2name:
          tax123: 'myTax'

      product =
        id: '123'
        masterVariant:
          attributes: []
        taxCategory:
          id: 'tax123'
      type =
        name: 'myType'
        id: 'typeId123'
      row = @exportMapping._mapBaseProduct(product, type)
      expect(row).toEqual [ 'myTax' ]


    it 'should map localized base attributes', ->
      @exportMapping.header = new Header(['name.de','slug.it','description.en'])
      @exportMapping.header.toIndex()
      product =
        id: '123'
        masterVariant:
          attributes: []
        name:
          de: 'Hallo'
          en: 'Hello'
          it: 'Ciao'
        slug:
          de: 'hallo'
          en: 'hello'
          it: 'ciao'
        description:
          de: 'Bla bla'
          en: 'Foo bar'
          it: 'Ciao Bella'

      row = @exportMapping._mapBaseProduct(product, {})
      expect(row).toEqual [ 'Hallo', 'ciao', 'Foo bar' ]

  describe '#createTemplate', ->
    beforeEach ->
      @productType =
        attributes: []
    
    it 'should do nothing if there are no attributes', ->
      template = @exportMapping.createTemplate @productType
      expect(template).toEqual CONS.ALL_HEADERS

    it 'should get attribute name for all kind of types', ->
      @productType.attributes.push { name: 'a-enum', type: { name: 'enum' } }
      @productType.attributes.push { name: 'a-lenum', type: { name: 'lenum' } }
      @productType.attributes.push { name: 'a-text', type: { name: 'text' } }
      @productType.attributes.push { name: 'a-number', type: { name: 'number' } }
      @productType.attributes.push { name: 'a-money', type: { name: 'money' } }
      @productType.attributes.push { name: 'a-date', type: { name: 'date' } }
      @productType.attributes.push { name: 'a-time', type: { name: 'time' } }
      @productType.attributes.push { name: 'a-datetime', type: { name: 'datetime' } }
      template = @exportMapping.createTemplate @productType
      expect(template).toEqual CONS.ALL_HEADERS.concat([ 'a-enum', 'a-lenum', 'a-text', 'a-number', 'a-money', 'a-date', 'a-time', 'a-datetime' ])

    it 'should add headers for all languages', ->
      @productType.attributes.push { name: 'multilang', type: { name: 'ltext' } }
      template = @exportMapping.createTemplate @productType, [ 'de', 'en', 'it' ]
      expect(template).toEqual CONS.ALL_HEADERS.concat([ 'multilang.de', 'multilang.en', 'multilang.it' ])
