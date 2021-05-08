{ createRequestBuilder } = require '@commercetools/api-request-builder'
_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'

exports.uniqueId = uniqueId = (prefix) ->
  _.uniqueId "#{prefix}#{new Date().getTime()}_"

getAllAttributesByConstraint = (constraint) ->
  lowerConstraint = switch constraint
    when 'Unique' then 'u'
    when 'CombinationUnique' then 'cu'
    when 'SameForAll' then 'sfa'
    else 'n'

  [
    { type: { name: 'text' }, name: "attr-text-#{lowerConstraint}", label: { en: "Attribute TEXT #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
    { type: { name: 'ltext' }, name: "attr-ltext-#{lowerConstraint}", label: { en: "Attribute LTEXT #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
    { type: { name: 'enum', values: [{ key: 'enum1', label: 'Enum1' }, { key: 'enum2', label: 'Enum2' }]}, name: "attr-enum-#{lowerConstraint}", label: { en: "Attribute ENUM #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'lenum', values: [{ key: 'lenum1', label: { en: 'Enum1' } }, { key: 'lenum2', label: { en: 'Enum2' } }]}, name: "attr-lenum-#{lowerConstraint}", label: { en: "Attribute LENUM #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'number' }, name: "attr-number-#{lowerConstraint}", label: { en: "Attribute NUMBER #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'boolean' }, name: "attr-boolean-#{lowerConstraint}", label: { en: "Attribute BOOLEAN #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'money' }, name: "attr-money-#{lowerConstraint}", label: { en: "Attribute MONEY #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'date' }, name: "attr-date-#{lowerConstraint}", label: { en: "Attribute DATE #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'time' }, name: "attr-time-#{lowerConstraint}", label: { en: "Attribute TIME #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'datetime' }, name: "attr-datetime-#{lowerConstraint}", label: { en: "Attribute DATETIME #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'reference', referenceTypeId: 'product' }, name: "attr-ref-product-#{lowerConstraint}", label: { en: "Attribute REFERENCE-PRODUCT #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'reference', referenceTypeId: 'product-type' }, name: "attr-ref-product-type-#{lowerConstraint}", label: { en: "Attribute REFERENCE-PRODUCT-TYPE #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'reference', referenceTypeId: 'channel' }, name: "attr-ref-channel-#{lowerConstraint}", label: { en: "Attribute REFERENCE-CHANNEL #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'reference', referenceTypeId: 'state' }, name: "attr-ref-state-#{lowerConstraint}", label: { en: "Attribute REFERENCE-STATE #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'reference', referenceTypeId: 'zone' }, name: "attr-ref-zone-#{lowerConstraint}", label: { en: "Attribute REFERENCE-ZONE #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'reference', referenceTypeId: 'shipping-method' }, name: "attr-ref-shipping-method-#{lowerConstraint}", label: { en: "Attribute REFERENCE-SHIPPING-METHOD #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'reference', referenceTypeId: 'category' }, name: "attr-ref-category-#{lowerConstraint}", label: { en: "Attribute REFERENCE-CATEGORY #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'reference', referenceTypeId: 'review' }, name: "attr-ref-review-#{lowerConstraint}", label: { en: "Attribute REFERENCE-REVIEW #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'reference', referenceTypeId: 'key-value-document' }, name: "attr-ref-key-value-#{lowerConstraint}", label: { en: "Attribute REFERENCE-KEY-VALUE-DOCUMENT #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'text' } }, name: "attr-set-text-#{lowerConstraint}", label: { en: "Attribute SET-TEXT #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
    { type: { name: 'set', elementType: { name: 'ltext' } }, name: "attr-set-ltext-#{lowerConstraint}", label: { en: "Attribute SET-LTEXT #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false, inputHint: 'SingleLine' }
    { type: { name: 'set', elementType: { name: 'enum', values: [{ key: 'enum1', label: 'Enum1' }, { key: 'enum2', label: 'Enum2' }] } }, name: "attr-set-enum-#{lowerConstraint}", label: { en: "Attribute SET-ENUM #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'lenum', values: [{ key: 'lenum1', label: { en: 'Enum1' } }, { key: 'lenum2', label: { en: 'Enum2' } }] } }, name: "attr-set-lenum-#{lowerConstraint}", label: { en: "Attribute SET-LENUM #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'number' } }, name: "attr-set-number-#{lowerConstraint}", label: { en: "Attribute SET-NUMBER #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'boolean' } }, name: "attr-set-boolean-#{lowerConstraint}", label: { en: "Attribute SET-BOOLEAN #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'money' } }, name: "attr-set-money-#{lowerConstraint}", label: { en: "Attribute SET-MONEY #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'date' } }, name: "attr-set-date-#{lowerConstraint}", label: { en: "Attribute SET-DATE #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'time' } }, name: "attr-set-time-#{lowerConstraint}", label: { en: "Attribute SET-TIME #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'datetime' } }, name: "attr-set-datetime-#{lowerConstraint}", label: { en: "Attribute SET-DATETIME #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'reference', referenceTypeId: 'product' } }, name: "attr-set-ref-product-#{lowerConstraint}", label: { en: "Attribute SET-REFERENCE-PRODUCT #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'reference', referenceTypeId: 'product-type' } }, name: "attr-set-ref-product-type-#{lowerConstraint}", label: { en: "Attribute SET-REFERENCE-PRODUCT-TYPE #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'reference', referenceTypeId: 'channel' } }, name: "attr-set-ref-channel-#{lowerConstraint}", label: { en: "Attribute SET-REFERENCE-CHANNEL #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'reference', referenceTypeId: 'state' } }, name: "attr-set-ref-state-#{lowerConstraint}", label: { en: "Attribute SET-REFERENCE-STATE #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'reference', referenceTypeId: 'zone' } }, name: "attr-set-ref-zone-#{lowerConstraint}", label: { en: "Attribute SET-REFERENCE-ZONE #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'reference', referenceTypeId: 'shipping-method' } }, name: "attr-set-ref-shipping-method-#{lowerConstraint}", label: { en: "Attribute SET-REFERENCE-SHIPPING-METHOD #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'reference', referenceTypeId: 'category' } }, name: "attr-set-ref-category-#{lowerConstraint}", label: { en: "Attribute SET-REFERENCE-CATEGORY #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'reference', referenceTypeId: 'review' } }, name: "attr-set-ref-review-#{lowerConstraint}", label: { en: "Attribute SET-REFERENCE-REVIEW #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
    { type: { name: 'set', elementType: { name: 'reference', referenceTypeId: 'key-value-document' } }, name: "attr-set-ref-key-value-#{lowerConstraint}", label: { en: "Attribute SET-REFERENCE-KEY-VALUE-DOCUMENT #{constraint}" }, attributeConstraint: constraint, isRequired: false, isSearchable: false }
  ]

exports.mockProductType = ->
  name: 'ImpEx with all types'
  description: 'A generic type with all attributes'
  attributes: _.flatten(_.map ['None', 'Unique', 'CombinationUnique', 'SameForAll'], (constraint) ->
    getAllAttributesByConstraint(constraint))

exports.cleanupProducts = (client, projectKey) ->
  console.log 'About to cleanup products...'
  productProjectionUri = createService(projectKey, 'productProjections')
    .sort('id')
    .where('published = "true"')
    .perPage(30)
    .build()

  productProjectionRequest = {
    uri: productProjectionUri
    method: 'GET'
  }
  client.process productProjectionRequest, (payload) ->
    Promise.map payload.body.results, (existingProduct) ->
      data = {
        id: existingProduct.id
        version: existingProduct.version
        actions: [
          action: 'unpublish'
        ]
      }
      unublishService = createService(projectKey, 'products')
      unpublishRequest = {
        uri: unublishService.byId(existingProduct.id).build()
        method: 'POST'
        body: data
      }
      client.execute(unpublishRequest)
  .then ->
    service = createService(projectKey, 'products')
    request = {
      uri: service.perPage(30).build()
      method: 'GET'
    }
    client.process request, (payload) ->
      Promise.map payload.body.results, (existingProduct) ->
        deleteService = createService(projectKey, 'products')
        deleteRequest = {
          uri: deleteService
            .byId(existingProduct.id)
            .withVersion(existingProduct.version)
            .build()
          method: 'DELETE'
        }
        client.execute(deleteRequest)
  .then (result) ->
    console.log "Deleted #{_.size result} products"
    result

###
 * You may omit the product in this case it resolves the created product type.
 * Otherwise the created product is resolved.
###
exports.setupProductType = (client, productType, product, projectKey) ->
  exports.cleanupProducts(client, projectKey)
  .then ->
    console.log "About to ensure productType"
    # ensure the productType exists, otherwise create it
    service = createService(projectKey, 'productTypes')
    request = {
      uri: service.where("name = \"#{productType.name}\"").perPage(1).build()
      method: 'GET'
    }
    client.execute(request)
  .then (result) ->
    if _.size(result.body.results) > 0
      Promise.all(_.map(result.body.results, (result) ->
        existingProductType = result
        console.log "ProductType '#{existingProductType.name}' already exists - deleting"
        deleteService = createService(projectKey, 'productTypes')
        deleteRequest = {
        uri: deleteService
        .byId(existingProductType.id)
        .withVersion(existingProductType.version)
        .build()
        method: 'DELETE'
        }
        client.execute(deleteRequest)
      ))
  .then ->
    console.log "Ensuring productType '#{productType.name}'"
    service = createService(projectKey, 'productTypes')
    request = {
      uri: service.build()
      method: 'POST'
      body: productType
    }
    client.execute(request)
    .then (result) -> Promise.resolve(result.body)
  .then (pt) ->
    if product?
      product.productType.id = pt.id
      service = createService(projectKey, 'products')
      request = {
        uri: service.build()
        method: 'POST'
        body: product
      }
      client.execute(request)
      .then (result) ->
        Promise.resolve result.body # returns product
    else
      Promise.resolve pt # returns productType


exports.ensureCategories = (client, categoryList, projectKey) ->
  console.log 'About to cleanup categories...'
  service = createService(projectKey, 'categories')
  request = {
    uri: service.perPage(30).build()
    method: 'GET'
  }
  client.process request, (payload) ->
    Promise.map payload.body.results, (category) ->
      deleteService = createService(projectKey, 'categories')
      deleteRequest = {
        uri: deleteService
          .byId(category.id)
          .withVersion(category.version)
          .build()
        method: 'DELETE'
      }
      client.execute(deleteRequest)
  .then (result) ->
    console.log "Deleted #{_.size result} categories, creating new one"
    Promise.map categoryList, (category) ->
      service = createService(projectKey, 'categories')
      request = {
        uri: service.build()
        method: 'POST'
        body: category
      }
      client.execute(request)
      .then (result) -> result.body

exports.generateCategories = (len) ->
  categories = []
  for i in [1...len+1]
    categories.push(        {
      "name": {
        "en": "Catgeory#{i}"
      },
      "slug": {
        "en": "category-#{i}"
      },
      "externalId": "#{i}",
    })
  categories

exports.ensurePreviousState = (client, projectKey) ->
  # Check if states exist
  service = createService(projectKey, 'states')
  request = {
    uri: service
      .where("key=\"previous-state\"")
      .build()
    method: 'GET'
  }
  client.execute request
  .then (result) =>
    # Create the state if it doesn't exist else ignore
    if (!result.body.total)
      service = createService(projectKey, 'states')
      request = {
        uri: service.build()
        method: 'POST'
        body:
          key: 'previous-state'
          type: 'ProductState'
      }
      client.execute request

exports.ensureNextState = (client, projectKey) ->
  # Check if states exist
  service = createService(projectKey, 'states')
  request = {
    uri: service
      .where("key=\"next-state\"")
      .build()
    method: 'GET'
  }
  client.execute request
  .then (result) =>
    # Create the state if it doesn't exist else ignore
    if (!result.body.total)
      service = createService(projectKey, 'states')
      request = {
        uri: service.build()
        method: 'POST'
        body:
          key: 'next-state'
          type: 'ProductState'
      }
      client.execute request

exports.ensureChannels = (client, projectKey, channelKey) ->
  # Check if channel exists
  service = createService(projectKey, 'channels')
  request = {
    uri: service
      .where("key=\"#{channelKey}\"")
      .build()
    method: 'GET'
  }
  client.execute request
  .then (result) =>
    # Create the channel if it doesn't exist else ignore
    if (!result.body.total)
      service = createService(projectKey, 'channels')
      request = {
        uri: service.build()
        method: 'POST'
        body:
          key: channelKey
          roles: ['InventorySupply']
      }
      client.execute request

createService = (projectKey, type) ->
  service = createRequestBuilder({ projectKey })[type]
  service

# This enables this function work in this file and in the test files
exports.createService = createService
