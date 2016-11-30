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
      console.log "ProductType '#{productType.name}' already exists"
      Promise.resolve(_.first(result.body.results))
    else
      console.log "Ensuring productType '#{productType.name}'"
      client.productTypes.create(productType)
      .then (result) -> Promise.resolve(result.body)
  .then (pt) ->
    if product?
      product.productType.id = pt.id
      client.products.create(product)
      .then (result) -> Promise.resolve result.body # returns product
    else
      Promise.resolve pt # returns productType


exports.ensureCategories = (client, categoryList) ->
  console.log 'About to cleanup categories...'
  client.categories
  .perPage(30)
  .process (res) ->
    Promise.map res.body.results, (category) ->
      client.categories.byId(category.id).delete(category.version)
  .then (result) ->
    console.log "Deleted #{_.size result} categories, creating new one"
    Promise.map categoryList, (category) ->
      client.categories.create(category)
      .then (result) -> Promise.resolve(result.body)
