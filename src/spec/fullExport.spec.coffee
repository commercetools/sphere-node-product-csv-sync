{ Export } = require '../lib/main'
Config = require '../config'
_ = require 'underscore'

describe 'Export', ->

  beforeEach ->
    @exporter = new Export({ client: Config })

  describe 'Function to filter out duplicate header entries', ->

    it 'should remove duplicate header entries', ->
      header = [
        'booleans',
        'categories',
        'channels',
        'customObjects',
        'numbers',
        'prices',
        'productType',
        'channels',
        'productTypes',
        'categories',
        'variantId' ]

      headerFiltered = [
        'booleans',
        'categories',
        'channels',
        'customObjects',
        'numbers',
        'prices',
        'productType',
        'productTypes',
        'variantId' ]

      expect(@exporter._removeDuplicities(header)).toEqual headerFiltered