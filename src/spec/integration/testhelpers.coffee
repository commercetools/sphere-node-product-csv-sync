_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'

###
 * You may omit the product in this case it resolves the created product type.
 * Otherwise the created product is resolved.
###
exports.setupProductType = (client, productType, product) ->
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
  .then -> client.productTypes.all().fetch()
  .then (result) ->
    Promise.map result.body.results, (productType) ->
      client.productTypes.byId(productType.id).delete(productType.version)
  .then -> client.productTypes.create(productType)
  .then (result) ->
    if product?
      product.productType.id = result.body.id
      client.products.create(product).then (result) ->
        Promise.resolve result.body
    else
      Promise.resolve result.body
