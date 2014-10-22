_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'

exports.uniqueId = (prefix) ->
  _.uniqueId "#{prefix}#{new Date().getTime()}_"

###
 * You may omit the product in this case it resolves the created product type.
 * Otherwise the created product is resolved.
###
exports.setupProductType = (client, productType, product) ->
  console.log 'About to cleanup products...'
  client.productProjections
  .sort('id')
  .where('published = "true"')
  .perPage(30)
  .process (payload) ->
    Promise.map payload.body.results, (existingProduct) ->
      data =
        id: existingProduct.id
        version: existingProduct.version
        actions: [
          action: 'unpublish'
        ]
      client.products.byId(existingProduct.id).update(data)
  .then ->
    client.products.perPage(30).process (payload) ->
      Promise.map payload.body.results, (existingProduct) ->
        client.products.byId(existingProduct.id).delete(existingProduct.version)
  .then (result) ->
    console.log "Deleted #{_.size result} products, about to ensure productType"
    # ensure the productType exists, otherwise create it
    client.productTypes.where("name = \"#{productType.name}\"").perPage(1).fetch()
  .then (result) ->
    if _.size(result.body.results) > 0
      console.log "ProductType #{productType.name} already exists"
      Promise.resolve(_.first(result.body.results))
    else
      console.log "Ensuring productType #{productType.name}"
      client.productTypes.create(productType)
      .then (result) -> Promise.resolve(result.body)
  .then (pt) ->
    if product?
      product.productType.id = pt.id
      client.products.create(product)
      .then (result) -> Promise.resolve result.body # returns product
    else
      Promise.resolve pt # returns productType
