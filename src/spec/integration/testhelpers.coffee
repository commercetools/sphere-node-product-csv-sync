Q = require 'q'
_ = require 'underscore'

###
 * You may omit the product in this case it resolves the created product type.
 * Otherwise the created product is resolved.
###
exports.setup = (client, productType, product) ->
  deferred = Q.defer()
  client.products.sort('id').where('masterData(published = "true")').process (payload) ->
    Q.all _.map payload.body.results, (existingProduct) ->
      data =
        id: existingProduct.id
        version: existingProduct.version
        actions: [
          action: 'unpublish'
        ]
      client.products.byId(existingProduct.id).update(data)
  .then ->
    client.products.all().fetch()
  .then (result) ->
    Q.all _.map result.body.results, (existingProduct) ->
      client.products.byId(existingProduct.id).delete(existingProduct.version)
  .then ->
    client.productTypes.all().fetch()
  .then (result) ->
    deletions = _.map result.body.results, (productType) ->
      client.productTypes.byId(productType.id).delete(productType.version)
    Q.all(deletions)
  .then ->
    client.productTypes.create(productType)
  .then (result) ->
    if product?
      product.productType.id = result.body.id
      client.products.create(product).then (result) ->
        deferred.resolve result.body
    else
      deferred.resolve result.body
  .fail (err) ->
    deferred.reject err
  .done()

  deferred.promise
