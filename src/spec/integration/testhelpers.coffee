Q = require 'q'
_ = require 'underscore'

exports.setup = (client, productType, product, done) ->
  client.products.sort('id').where('masterData(published = "true")').process (payload) ->
    Q.all _.map payload.body.results, (product) ->
      data =
        id: product.id
        version: product.version
        actions: [
          action: 'unpublish'
        ]
      client.products.byId(product.id).update(data)
  .then ->
    client.products.all().fetch()
  .then (result) ->
    Q.all _.map result.body.results, (product) ->
      client.products.byId(product.id).delete(product.version)
  .then ->
    client.productTypes.all().fetch()
  .then (result) ->
    deletions = _.map result.body.results, (productType) ->
      client.productTypes.byId(productType.id).delete(productType.version)
    Q.all(deletions)
  .then ->
    client.productTypes.create(productType)
  .then (result) ->
    product.productType.id = result.body.id
    client.products.create(product)
  .then (result) ->
    done()
  .fail (err) ->
    done(_.prettify err)
  .done()
