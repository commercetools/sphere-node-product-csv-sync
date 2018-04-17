/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore')
_.mixin(require('underscore.string').exports())
const Promise = require('bluebird')
const Csv = require('csv')
const { SphereClient } = require('sphere-node-sdk')
const CONS = require('./constants')
const GLOBALS = require('./globals')
const Mapping = require('./mapping')
const Header = require('./header')

class Validator {
  constructor (options) {
    this.serialize = this.serialize.bind(this)
    this.fetchResources = this.fetchResources.bind(this)
    if (options == null) options = {}
    this.types = options.types
    this.customerGroups = options.customerGroups
    this.categories = options.categories
    this.taxes = options.taxes
    this.channels = options.channels

    options.validator = this
    // TODO:
    // - pass only correct options, not all classes
    // - avoid creating a new instance of the client, since it should be created from Import class
    if (options.config) this.client = new SphereClient(options)
    this.rawProducts = []
    this.errors = []
    this.suppressMissingHeaderWarning = false
    this.csvOptions = {
      delimiter: options.csvDelimiter || ',',
      quote: options.csvQuote || '"',
      trim: true,
    }
  }

  parse (csvString) {
    // TODO: use parser with streaming API
    // https://github.com/sphereio/sphere-node-product-csv-sync/issues/56
    return new Promise((resolve, reject) => Csv().from.string(csvString, this.csvOptions)
      .on('error', error => reject(error))
      .to.array((data) => {
        data = this.serialize(data)
        return resolve(data)
      }))
  }

  serialize (data) {
    this.header = new Header(data[0])
    return {
      header: this.header,
      data: _.rest(data),
      count: data.length,
    }
  }

  validate (csvContent) {
    this.validateOffline(csvContent)
    return this.validateOnline()
  }

  validateOffline (csvContent) {
    let variantHeader
    this.header.validate()
    this.checkDelimiters()

    if (this.header.has(CONS.HEADER_VARIANT_ID)) variantHeader = CONS.HEADER_VARIANT_ID
    if (this.header.has(CONS.HEADER_SKU) && (variantHeader == null)) {
      variantHeader = CONS.HEADER_SKU
      this.updateVariantsOnly = true
    }
    return this.buildProducts(csvContent, variantHeader)
  }

  checkDelimiters () {
    const allDelimiter = {
      csvDelimiter: this.csvOptions.delimiter,
      csvQuote: this.csvOptions.quote,
      language: GLOBALS.DELIM_HEADER_LANGUAGE,
      multiValue: GLOBALS.DELIM_MULTI_VALUE,
      categoryChildren: GLOBALS.DELIM_CATEGORY_CHILD,
    }
    const delims = _.map(allDelimiter, (delim, _) => delim)
    if (_.size(delims) !== _.size(_.uniq(delims)))
      return this.errors.push(`Your selected delimiter clash with each other: ${JSON.stringify(allDelimiter)}`)
  }

  fetchResources (cache) {
    let promise = Promise.resolve(cache)
    if (!cache)
      promise = Promise.all([
        this.types.getAll(this.client),
        this.customerGroups.getAll(this.client),
        this.categories.getAll(this.client),
        this.taxes.getAll(this.client),
        this.channels.getAll(this.client),
      ])


    return promise
      .then((resources) => {
        const [productTypes, customerGroups, categories, taxes, channels] = Array.from(resources)
        this.productTypes = productTypes.body.results
        this.types.buildMaps(this.productTypes)
        this.customerGroups.buildMaps(customerGroups.body.results)
        this.categories.buildMaps(categories.body.results)
        this.taxes.buildMaps(taxes.body.results)
        this.channels.buildMaps(channels.body.results)
        return Promise.resolve(resources)
      })
  }

  validateOnline () {
    // TODO: too much parallel?
    // TODO: is it ok storing everything in memory?
    this.valProducts(this.rawProducts) // TODO: ???
    if (_.size(this.errors) === 0) {
      this.valProductTypes(this.productTypes) // TODO: ???
      if (_.size(this.errors) === 0)
        return Promise.resolve(this.rawProducts)
      return Promise.reject(this.errors)
    } return Promise.reject(this.errors)
  }

  shouldPublish (csvRow) {
    if (!this.header.has(CONS.HEADER_PUBLISH))
      return false

    return csvRow[this.header.toIndex(CONS.HEADER_PUBLISH)] === 'true'
  }

  // TODO: Allow to define a column that defines the variant relationship.
  // If the value is the same, they belong to the same product
  buildProducts (content, variantColumn) {
    const buildVariantsOnly = (aggr, row, index) => {
      const rowIndex = index + 2 // Excel et all start counting at 1 and we already popped the header
      const productTypeIndex = this.header.toIndex(CONS.HEADER_PRODUCT_TYPE)
      const productType = row[productTypeIndex]
      let lastProduct = _.last(this.rawProducts)

      // if there is no productType and no product above
      // skip this line
      if (!productType && !lastProduct) {
        this.errors.push(`[row ${rowIndex}] Please provide a product type!`)
        return aggr
      }

      if (!productType) {
        console.warn(`[row ${rowIndex}] Using previous productType for variant update`)
        lastProduct = _.last(this.rawProducts)
        row[productTypeIndex] = lastProduct.master[productTypeIndex]
      }

      this.rawProducts.push({
        master: _.deepClone(row),
        startRow: rowIndex,
        variants: [],
        publish: this.shouldPublish(row),
      })

      return aggr
    }

    const buildProductsOnFly = (aggr, row, index) => {
      let product
      const rowIndex = index + 2 // Excel et all start counting at 1 and we already popped the header
      const publish = this.shouldPublish(row)
      if (this.isProduct(row, variantColumn)) {
        product = {
          master: row,
          startRow: rowIndex,
          variants: [],
          publish,
        }
        this.rawProducts.push(product)
      } else if (this.isVariant(row, variantColumn)) {
        product = _.last(this.rawProducts)
        if (product) {
          product.variants.push({
            variant: row,
            rowIndex,
          })
          if (publish)
            product.publish = true
        } else
          this.errors.push(`[row ${rowIndex}] We need a product before starting with a variant!`)
      } else
        this.errors.push(`[row ${rowIndex}] Could not be identified as product or variant!`)

      return aggr
    }

    const reducer = this.updateVariantsOnly ?
      buildVariantsOnly
      : buildProductsOnFly
    return content.reduce(reducer, {})
  }

  valProductTypes (productTypes) {
    if (this.suppressMissingHeaderWarning) return
    return _.each(productTypes, (pt) => {
      const attributes = this.header.missingHeaderForProductType(pt)
      if (!_.isEmpty(attributes)) {
        console.warn(`For the product type '${pt.name}' the following attributes don't have a matching header:`)
        return _.each(attributes, attr => console.warn(`  ${attr.name}: type '${attr.type.name} ${attr.type.name === 'set' ? `of ${attr.type.elementType.name}` : ''}' - constraint '${attr.attributeConstraint}' - ${attr.isRequired ? 'isRequired' : 'optional'}`))
      }
    })
  }

  valProducts (products) {
    return _.each(products, product => this.valProduct(product))
  }

  valProduct (raw) {
    const rawMaster = raw.master
    let ptInfo = rawMaster[this.header.toIndex(CONS.HEADER_PRODUCT_TYPE)]

    if (_.contains(this.types.duplicateNames, ptInfo)) this.errors.push(`[row ${raw.startRow}] The product type name '${ptInfo}' is not unique. Please use the ID!`)

    if (_.has(this.types.name2id, ptInfo))
      ptInfo = this.types.name2id[ptInfo]

    if (_.has(this.types.id2index, ptInfo)) {
      const index = this.types.id2index[ptInfo]
      return rawMaster[this.header.toIndex(CONS.HEADER_PRODUCT_TYPE)] = this.productTypes[index]
    } return this.errors.push(`[row ${raw.startRow}] Can't find product type for '${ptInfo}'`)
  }

  isVariant (row, variantColumn) {
    if (variantColumn === CONS.HEADER_VARIANT_ID) {
      const variantId = row[this.header.toIndex(CONS.HEADER_VARIANT_ID)]
      return parseInt(variantId) > 1
    } return !this.isProduct(row)
  }

  isProduct (row, variantColumn) {
    const hasProductTypeColumn = !_.isBlank(row[this.header.toIndex(CONS.HEADER_PRODUCT_TYPE)])
    if (variantColumn === CONS.HEADER_VARIANT_ID)
      return hasProductTypeColumn && (row[this.header.toIndex(CONS.HEADER_VARIANT_ID)] === '1')
    return hasProductTypeColumn
  }

  _hasVariantCriteria (row, variantColumn) {
    const critertia = row[this.header.toIndex(variantColumn)]
    return (critertia != null)
  }
}

module.exports = Validator
