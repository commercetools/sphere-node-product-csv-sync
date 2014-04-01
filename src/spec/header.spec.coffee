_ = require('underscore')._
Header = require '../lib/header'
Validator = require '../lib/validator'
CONS = require '../lib/constants'

describe 'Header', ->
  beforeEach ->
    @validator = new Validator()

  describe '#constructor', ->
    it 'should initialize', ->
      expect(-> new Header()).toBeDefined()

    it 'should initialize rawHeader', ->
      header = new Header ['name']
      expect(header.rawHeader).toEqual ['name']

  describe '#validate', ->
    it 'should return error for each missing header', (done) ->
      csv =
        """
        foo,productType
        1,2
        """
      @validator.parse csv, =>
        errors = @validator.header.validate()
        expect(errors.length).toBe 1
        expect(errors[0]).toBe "Can't find necessary base header 'variantId'!"
        done()

    it 'should return error on duplicate header', (done) ->
      csv =
        """
        productType,name,variantId,name
        1,2,3,4
        """
      @validator.parse csv, =>
        errors = @validator.header.validate()
        expect(errors.length).toBe 1
        expect(errors[0]).toBe "There are duplicate header entries!"
        done()

  describe '#toIndex', ->
    it 'should create mapping', (done) ->
      csv =
        """
        productType,foo,variantId
        1,2,3
        """
      @validator.parse csv, =>
        h2i = @validator.header.toIndex()
        expect(_.size h2i).toBe 3
        expect(h2i['productType']).toBe 0
        expect(h2i['foo']).toBe 1
        expect(h2i['variantId']).toBe 2
        done()

  describe '#_productTypeLanguageIndexes', ->
    beforeEach ->
      @productType =
        id: '213'
        attributes: [
          name: 'foo'
          type:
            name: 'ltext'
        ]
      @csv =
        """
        someHeader,foo.en,foo.de
        """
    it 'should create language header index for ltext attributes', (done) ->
      @validator.parse @csv, =>
        langH2i = @validator.header._productTypeLanguageIndexes @productType
        expect(_.size langH2i).toBe 1
        expect(_.size langH2i['foo']).toBe 2
        expect(langH2i['foo']['de']).toBe 2
        expect(langH2i['foo']['en']).toBe 1
        done()

    it 'should provide access via productType', (done) ->
      @validator.parse @csv, =>
        expected =
          de: 2
          en: 1
        expect(@validator.header.productTypeAttributeToIndex(@productType, @productType.attributes[0])).toEqual expected
        done()

  describe '#_languageToIndex', ->
    it 'should create mapping for language attributes', (done) ->
      csv =
        """
        foo,a1.de,bar,a1.it
        """
      @validator.parse csv, =>
        langH2i = @validator.header._languageToIndex(['a1'])
        expect(_.size langH2i).toBe 1
        expect(_.size langH2i['a1']).toBe 2
        expect(langH2i['a1']['de']).toBe 1
        expect(langH2i['a1']['it']).toBe 3
        done()

  describe '#missingHeaderForProductType', ->
    it 'should give list of attributes that are not covered by headers', ->
      csv =
        """
        foo,a1.de,bar,a1.it
        """
      productType =
        id: 'whatAtype'
        attributes: [
          { name: 'foo', type: { name: 'text' } }
          { name: 'bar', type: { name: 'enum' } }
          { name: 'a1', type: { name: 'ltext' } }
          { name: 'a2', type: { name: 'set' } }
        ]
      @validator.parse csv, =>
        header = @validator.header
        header.toIndex()
        header.toLanguageIndex()
        missingHeaders = header.missingHeaderForProductType(productType)
        console.log "MISSING %j", missingHeaders
        expect(_.size missingHeaders).toBe 1
        expect(missingHeaders[0]).toEqual { name: 'a2', type: { name: 'set' } }
