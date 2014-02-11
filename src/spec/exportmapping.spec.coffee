_ = require('underscore')._
ExportMapping = require '../lib/exportmapping'
Header = require '../lib/header'
CONS = require '../lib/constants'

describe 'ExportMapping', ->
  beforeEach ->
    @exportMapping = new ExportMapping()

  describe '#constructor', ->
    it 'should initialize', ->
      expect(-> new ExportMapping()).toBeDefined()

  describe '#mapAttribute', ->
    it 'should map simple attribute', ->
      attribute =
        name: 'foo'
        value: 'some text'
      expect(@exportMapping.mapAttribute attribute).toBe 'some text'

    it 'should map enum attribute', ->
      attribute =
        name: 'foo'
        value:
          label:
            en: 'bla'
          key: 'myEnum'
      expect(@exportMapping.mapAttribute attribute).toBe 'myEnum'

    it 'should map text set attribute', ->
      attribute =
        name: 'foo'
        value: [ 'x', 'y', 'z' ]
      expect(@exportMapping.mapAttribute attribute).toBe 'x;y;z'

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
      expect(@exportMapping.mapAttribute attribute).toBe 'myEnum;myEnum2'

  describe '#mapVariant', ->
    it 'should map variant id and sku', ->
      @exportMapping.header = new Header([CONS.HEADER_VARIANT_ID, CONS.HEADER_SKU])
      @exportMapping.header.toIndex()
      variant =
        id: '12'
        sku: 'mySKU'
        attributes: []
      row = @exportMapping.mapVariant(variant)
      expect(row).toEqual [ '12', 'mySKU' ]

    it 'should map variant attributes', ->
      @exportMapping.header = new Header([ 'foo' ])
      @exportMapping.header.toIndex()
      variant =
        attributes: [
          { name: 'foo', value: 'bar' }
        ]
      row = @exportMapping.mapVariant(variant)
      expect(row).toEqual [ 'bar' ]

  describe '#mapBaseProduct', ->
    it 'should map productType and id', ->
      @exportMapping.header = new Header([CONS.HEADER_PRODUCT_TYPE,CONS.HEADER_ID])
      @exportMapping.header.toIndex()
      product =
        id: '123'
      type =
        id: 'typeId123'
      row = @exportMapping.mapBaseProduct([], product, type)
      expect(row).toEqual [ 'typeId123', '123' ]

    it 'should map localized base attributes', ->
      @exportMapping.header = new Header(['name.de','slug.it','description.en'])
      @exportMapping.header.toIndex()
      product =
        id: '123'
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

      row = @exportMapping.mapBaseProduct([], product, {})
      expect(row).toEqual [ 'Hallo', 'ciao', 'Foo bar' ]
