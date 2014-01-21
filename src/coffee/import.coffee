_ = require 'underscore'
Validator = require '../lib/validator'

class Import
  constructor: (options = {}) ->
    @validator = new Validator options

  import: (fileContent, callback) ->
    @validator.parse fileContent, (data, count) =>
      @validator.validate(data).then (rawProducts) =>
        products = []
        for rawProduct in @validator.rawProducts
          products.push @validator.map.mapProduct(rawProduct)
        if _.size(@validator.errors) is 0
          for product in products
            @createOrUpdate product
        callback(true)
      .fail (msg) ->
        callback(false)

  createOrUpdate: (product) ->
    console.log "createOrUpdate %j", product


module.exports = Import