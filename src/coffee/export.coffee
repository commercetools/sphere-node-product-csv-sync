_ = require 'underscore'
Csv = require 'csv'
CONS = require '../lib/constants'
Types = require '../lib/types'
Header = require '../lib/header'
Rest = require('sphere-node-connect').Rest
CommonUpdater = require('sphere-node-sync').CommonUpdater
Q = require 'q'

class Export extends CommonUpdater

  constructor: (options = {}) ->
    super(options)
    @types = new Types()
    @rest = new Rest options if options.config

  export: (templateContent, outputFile, callback) ->
    @parse(templateContent).then (header) =>
      header.validate()
      # TODO: check validation result
      header.toIndex()
      header.toLanguageIndex()
      @header = header
      @types.getAll(@rest).then (productTypes) =>
        console.log "Number of product types: #{_.size productTypes}."
        @types.buildMaps productTypes
        @productTypes = productTypes
        for productType in productTypes
          @header._productTypeLanguageIndexes(productType)
        @getAllExistingProducts().then (products) =>
          console.log "Number of products: #{_.size products}."
          if _.size(products) is 0
            @returnResult true, 'No products found.', callback
          csv = [ header.rawHeader ]
          for product in products
            csv = csv.concat(@mapProduct(product))
          x = Csv().from(csv).to.path(outputFile)
        .fail (msg) ->
          @returnResult false, msg, callback
      .fail (msg) ->
        @returnResult false, msg, callback
    # TODO: check for failures on parsing

  parse: (csvString) ->
    deferred = Q.defer()
    Csv().from.string(csvString)
    .to.array (data, count) ->
      header = new Header(data[0])
      deferred.resolve header
    deferred.promise

  getAllExistingProducts: ->
    deferred = Q.defer()
    @rest.GET '/product-projections?limit=0&staged=false', (error, response, body) ->
      if error
        deferred.reject 'Error on getting existing products: ' + error
      else
        if response.statusCode is 200
          deferred.resolve JSON.parse(body).results
        else
          deferred.reject 'Problem on getting existing products: ' + body
    deferred.promise

  mapProduct: (product) ->
    productType = @productTypes[@types.id2index[product.productType.id]]
    masterRow = @mapVariant product.masterVariant, productType

    for attribName, h2i of @header.toLanguageIndex()
      for lang, index of h2i
        masterRow[index] = product[attribName][lang]

    rows = []
    rows.push masterRow

    if product.variants
      for variant in product.variants
        rows.push @mapVariant variant, productType
    rows

  mapVariant: (variant, productType) ->
    row = []
    if variant.attributes
      for attribute in variant.attributes
        if @header.has attribute.name
          row[@header.toIndex attribute.name] = @mapAttribute(attribute, productType)
        else # ltext attributes
          h2i = @header.productTypeAttributeToIndex productType, attribute.name
          if h2i
            for lang, index of h2i
              row[index] = attribute.value[lang]
    row

  mapAttribute: (attribute, productType) ->
    if _.has(attribute.value, 'key')
      attribute.value.key
    else
      if _.isArray attribute.value
        attribute.value.join CONS.DELIM_MULTI_VALUE
      else
        attribute.value


module.exports = Export