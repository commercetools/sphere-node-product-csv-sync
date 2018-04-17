/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS201: Simplify complex destructure assignments
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore')
_.mixin(require('underscore-mixins'))
const Promise = require('bluebird')
const { SphereClient, ProductSync, Errors } = require('sphere-node-sdk')
const { Repeater } = require('sphere-node-utils')
const CONS = require('./constants')
const GLOBALS = require('./globals')
const Validator = require('./validator')
const Mapping = require('./mapping')
const QueryUtils = require('./queryutils')
const MatchUtils = require('./matchutils')
const extractArchive = Promise.promisify(require('extract-zip'))
const path = require('path')
const tmp = require('tmp')
const walkSync = require('walk-sync')
const Reader = require('./io/reader')
const deepMerge = require('lodash.merge')
const fs = Promise.promisifyAll(require('fs'))

// will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup()

// API Types
const Types = require('./types')
const Categories = require('./categories')
const CustomerGroups = require('./customergroups')
const Taxes = require('./taxes')
const Channels = require('./channels')

// TODO:
// - better organize subcommands / classes / helpers
// - don't save partial results globally, instead pass them around to functions that need them
// - JSDoc
class Import {
  constructor (options) {
    this.initializeObjects = this.initializeObjects.bind(this)
    this.import = this.import.bind(this)
    if (options == null) options = {}
    if (options.config) { // for easier unit testing
      this.client = new SphereClient(options)
      this.client.setMaxParallel(10)
      this.sync = new ProductSync()
      this.repeater = new Repeater({ attempts: 3 })
    }

    options.importFormat = options.importFormat || 'csv'
    options.csvDelimiter = options.csvDelimiter || ','
    options.encoding = options.encoding || 'utf-8'
    options.mergeCategoryOrderHints = Boolean(options.mergeCategoryOrderHints)
    this.dryRun = false
    this.updatesOnly = false
    this.publishProducts = false
    this.continueOnProblems = options.continueOnProblems
    this.mergeCategoryOrderHints = options.mergeCategoryOrderHints
    this.allowRemovalOfVariants = false
    this.blackListedCustomAttributesForUpdate = []
    this.customAttributeNameToMatch = undefined
    this.matchBy = CONS.HEADER_ID
    this.options = options
    this._BATCH_SIZE = 20
    this._CONCURRENCY = 20
  }

  initializeObjects () {
    console.log('Initializing resources')
    this.options.types = new Types()
    this.options.customerGroups = new CustomerGroups()
    this.options.categories = new Categories()
    this.options.taxes = new Taxes()
    this.options.channels = new Channels()

    this.validator = new Validator(this.options)
    this.validator.suppressMissingHeaderWarning = this.suppressMissingHeaderWarning
    return this.map = new Mapping(this.options)
  }


  // current workflow:
  // - parse csv
  // - validate csv
  // - map all parsed products
  // - get all existing products
  // - create/update products based on matches
  //
  // ideally workflow:
  // - get all product types, categories, customer groups, taxes, channels (maybe get them ondemand?)
  // - stream csv -> chunk (100)
  // - base csv validation of chunk
  // - map products to json in chunk
  // - lookup mapped products in sphere (depending on given matcher - id, sku, slug, custom attribute)
  // - validate products against their product types (we might not have to product type before)
  // - create/update products based on matches
  // - next chunk
  import (csv) {
    this.initializeObjects()

    return this.validator.fetchResources(this.resourceCache)
      .then((resources) => {
        this.resourceCache = resources

        if (_.isString(csv) || csv instanceof Buffer)
          return Reader.parseCsv(csv, this.options.csvDelimiter, this.options.encoding)


        return Promise.resolve(csv)
      }).then((parsed) => {
        parsed = this.validator.serialize(parsed)

        console.warn(`CSV file with ${parsed.count} row(s) loaded.`)
        this.map.header = parsed.header
        this.validator.validateOffline(parsed.data)
        if (_.size(this.validator.errors) !== 0)
          return Promise.reject(this.validator.errors)
        return this.validator.validateOnline()
          .then((rawProducts) => {
            if (_.size(this.validator.errors) !== 0)
              return Promise.reject(this.validator.errors)


            console.warn(`Mapping ${_.size(rawProducts)} product(s) ...`)
            const products = rawProducts.map(p => this.map.mapProduct(p))

            if (_.size(this.map.errors) !== 0)
              return Promise.reject(this.map.errors)

            console.warn('Mapping done. About to process existing product(s) ...')

            const p = this.validator.updateVariantsOnly ?
              p => this.processProductsBasesOnSkus(p)
              :
              p => this.processProducts(p)
            return Promise.map(_.batchList(products, this._BATCH_SIZE), p, { concurrency: this._CONCURRENCY })
              .then(results => _.flatten(results))
          })
      })
  }

  _unarchiveProducts (archivePath) {
    const tempDir = tmp.dirSync({ unsafeCleanup: true })
    console.log(`Unarchiving file ${archivePath}`)

    return extractArchive(archivePath, { dir: tempDir.name })
      .then(() => {
        const filePredicate = `**/*.${this.options.importFormat}`
        console.log(`Loading files '${filePredicate}'from`, tempDir.name)
        let filePaths = walkSync(tempDir.name, { globs: [filePredicate] })
        if (!filePaths.length)
          return Promise.reject(`There are no ${this.options.importFormat} files in archive`)


        filePaths = filePaths.map(fileName => path.join(tempDir.name, fileName))
        return Promise.resolve(filePaths)
      })
  }

  importManager (file, isArchived) {
    let fileListPromise = Promise.resolve([file])

    if (file && isArchived)
      fileListPromise = this._unarchiveProducts((file))


    return fileListPromise
      .map(
        (file) => {
          // classes have internal structures which has to be reinitialized
          const reader = new Reader({
            csvDelimiter: this.options.csvDelimiter,
            encoding: this.options.encoding,
            importFormat: this.options.importFormat,
            debug: this.options.debug,
          })

          return reader.read(file)
            .then((rows) => {
              console.log('Loading has finished')
              return this.import(rows)
            })
        }

        , { concurrency: 1 },
      )
      .then(res => Promise.resolve(_.flatten(res))).catch((err) => {
        console.error(err.stack || err)
        return Promise.reject(err)
      })
  }

  processProducts (products) {
    const filterInput = QueryUtils.mapMatchFunction(this.matchBy)(products)
    return this.client.productProjections.staged().where(filterInput).fetch()
      .then((payload) => {
        const existingProducts = payload.body.results
        console.warn(`Comparing against ${payload.body.count} existing product(s) ...`)
        const matchFn = MatchUtils.initMatcher(this.matchBy, existingProducts)
        console.warn(`Processing ${_.size(products)} product(s) ...`)
        return this.createOrUpdate(products, this.validator.types, matchFn)
      })
      .then((result) => {
      // TODO: resolve with a summary of the import
        console.warn(`Finished processing ${_.size(result)} product(s)`)
        return Promise.resolve(result)
      })
  }

  isConcurrentModification (err) {
    return err.body.statusCode === 409
  }

  processProductsBasesOnSkus (products) {
    const filterInput = QueryUtils.mapMatchFunction('sku')(products)
    return this.client.productProjections.staged().where(filterInput).fetch()
      .then((payload) => {
        const existingProducts = payload.body.results
        console.warn(`Comparing against ${payload.body.count} existing product(s) ...`)
        const matchFn = MatchUtils.initMatcher('sku', existingProducts)
        const productsToUpdate = this.mapVariantsBasedOnSKUs(existingProducts, products)
        return Promise.all(_.map(productsToUpdate, (entry) => {
          const existingProduct = matchFn(entry)

          if (existingProduct)
            return this.update(entry.product, existingProduct, this.validator.types.id2SameForAllAttributes, entry.header, entry.rowIndex, entry.publish)
              .catch((msg) => {
                if (msg === 'ConcurrentModification') {
                  console.warn('Resending after concurrentModification error')
                  return this.processProductsBasesOnSkus(entry.entries)
                } return Promise.reject(msg)
              })

          console.warn('Ignoring not matched product')
          return Promise.resolve()
        }))
          .then((result) => {
            console.warn(`Finished processing ${_.size(result)} product(s)`)
            return Promise.resolve(result)
          })
      })
  }

  mapVariantsBasedOnSKUs (existingProducts, products) {
    console.warn(`Mapping variants for ${_.size(products)} product(s) ...`)
    // console.warn "existingProducts", _.prettify(existingProducts)
    // console.warn "products", _.prettify(products)
    const [sku2index, sku2variantInfo] = Array.from(existingProducts.reduce(
      (aggr, p, i) =>
        ([p.masterVariant].concat(p.variants)).reduce(
          (...args) => {
            const [s2i, s2v] = Array.from(args[0]),
              v = args[1],
              vi = args[2]
            s2i[v.sku] = i
            s2v[v.sku] = {
              index: vi - 1, // we reduce by one because of the masterVariant
              id: v.id,
            }
            return [s2i, s2v]
          }
          , aggr,
        )

      , [{}, {}],
    ))
    // console.warn "sku2index", _.prettify(sku2index)
    // console.warn "sku2variantInfo", _.prettify(sku2variantInfo)
    const productsToUpdate = {}
    _.each(products, (entry) => {
      const variant = entry.product.masterVariant
      // console.warn "variant", variant
      const productIndex = sku2index[variant.sku]
      // console.warn "variant.sku", variant.sku
      // console.warn "productIndex", productIndex
      if (productIndex != null) {
        const existingProduct = (productsToUpdate[productIndex] != null ? productsToUpdate[productIndex].product : undefined) || _.deepClone(existingProducts[productIndex])
        const entries = (productsToUpdate[productIndex] != null ? productsToUpdate[productIndex].entries : undefined) || []
        entries.push(entry)

        const variantInfo = sku2variantInfo[variant.sku]
        variant.id = variantInfo.id

        // If the variantId is 1, masterVariant will be matched
        // Otherwise it tries to match with the SKU
        // This means if the masterVariant has no SKU and the id is not 1, the
        // masterVariant will not be updated
        if ((variant.id === 1) || (variant.sku === existingProduct.masterVariant.sku))
          existingProduct.masterVariant = variant
        else
          existingProduct.variants[variantInfo.index] = variant


        if (!productsToUpdate[productIndex])
          productsToUpdate[productIndex] = {
            publish: false,
            rowIndex: entry.rowIndex,
          }


        return productsToUpdate[productIndex] = {
          product: this.mergeProductLevelInfo(existingProduct, _.deepClone(entry.product)),
          header: entry.header,
          entries,
          rowIndex: productsToUpdate[productIndex].rowIndex,
          publish: productsToUpdate[productIndex].publish || entry.publish,
        }
      } return console.warn('Ignoring variant as no match by SKU found for: ', variant)
    })
    return _.map(productsToUpdate)
  }

  mergeProductLevelInfo (finalProduct, product) {
    // Remove variants/masterVariant - should be already copied to final product
    delete product.variants
    delete product.masterVariant

    // if new categories are provided
    // remove old ones and deepMerge new categories
    if (product.categories)
      finalProduct.categories = []


    return deepMerge(finalProduct, product)
  }

  changeState (publish, remove, filterFunction) {
    if (publish == null) publish = true
    if (remove == null) remove = false
    this.publishProducts = true

    return this.client.productProjections.staged(remove || publish).perPage(500).process((result) => {
      const existingProducts = result.body.results

      console.warn(`Found ${_.size(existingProducts)} product(s) ...`)
      const filteredProducts = _.filter(existingProducts, filterFunction)
      console.warn(`Filtered ${_.size(filteredProducts)} product(s).`)

      if (_.size(filteredProducts) === 0)
        // Q 'Nothing to do.'
        return Promise.resolve()

      const posts = _.map(filteredProducts, (product) => {
        if (remove)
          return this.deleteProduct(product, 0)
        return this.publishProduct(product, 0, publish)
      })

      let action = publish ? 'Publishing' : 'Unpublishing'
      if (remove) action = 'Deleting'
      console.warn(`${action} ${_.size(posts)} product(s) ...`)
      return Promise.all(posts)
    }).then((result) => {
      const filteredResult = _.filter(result, r => r)
      // TODO: resolve with a summary of the import
      console.warn(`Finished processing ${_.size(filteredResult)} products`)
      if (_.size(filteredResult) === 0)
        return Promise.resolve('Nothing to do')

      return Promise.resolve(filteredResult)
    })
  }

  createOrUpdate (products, types, matchFn) {
    return Promise.all(_.map(products, (entry) => {
      const existingProduct = matchFn(entry)
      if (existingProduct != null)
        return this.update(entry.product, existingProduct, types.id2SameForAllAttributes, entry.header, entry.rowIndex, entry.publish)
          .catch((msg) => {
            if (msg === 'ConcurrentModification') {
              console.warn('Resending after concurrentModification error')
              return this.processProducts([entry], types, matchFn)
            } return Promise.reject(msg)
          })
      return this.create(entry.product, entry.rowIndex, entry.publish)
    }))
  }

  _mergeCategoryOrderHints (existingProduct, product) {
    if (this.mergeCategoryOrderHints)
      return deepMerge(product.categoryOrderHints, existingProduct.categoryOrderHints)
    return product.categoryOrderHints
  }

  _isBlackListedForUpdate (attributeName) {
    if (_.isEmpty(this.blackListedCustomAttributesForUpdate))
      return false
    return _.contains(this.blackListedCustomAttributesForUpdate, attributeName)
  }

  splitUpdateActionsArray (updateRequest, chunkSize) {
    const allActionsArray = updateRequest.actions
    let { version } = updateRequest

    const chunkifiedActionsArray = []
    let i = 0
    while (i < allActionsArray.length) {
      const update = { actions: allActionsArray.slice(i, i + chunkSize), version }
      chunkifiedActionsArray.push(update)
      version += chunkSize
      i += chunkSize
    }
    return chunkifiedActionsArray
  }

  update (product, existingProduct, id2SameForAllAttributes, header, rowIndex, publish) {
    product.categoryOrderHints = this._mergeCategoryOrderHints(existingProduct, product)
    const allSameValueAttributes = id2SameForAllAttributes[product.productType.id]
    const config = [
      { type: 'base', group: 'white' },
      { type: 'references', group: 'white' },
      { type: 'attributes', group: 'white' },
      { type: 'variants', group: 'white' },
      { type: 'categories', group: 'white' },
      { type: 'categoryOrderHints', group: 'white' },
    ]
    if (header.has(CONS.HEADER_PRICES))
      config.push({ type: 'prices', group: 'white' })
    else
      config.push({ type: 'prices', group: 'black' })

    if (header.has(CONS.HEADER_IMAGES))
      config.push({ type: 'images', group: 'white' })
    else
      config.push({ type: 'images', group: 'black' })

    const filtered = this.sync.config(config)
      .buildActions(product, existingProduct, allSameValueAttributes)
      .filterActions((action) => {
      // console.warn "ACTION", action
        switch (action.action) {
          case 'setAttribute': case 'setAttributeInAllVariants':
            return (header.has(action.name) || header.hasLanguageForCustomAttribute(action.name)) && !this._isBlackListedForUpdate(action.name)
          case 'changeName': return header.has(CONS.HEADER_NAME) || header.hasLanguageForBaseAttribute(CONS.HEADER_NAME)
          case 'changeSlug': return header.has(CONS.HEADER_SLUG) || header.hasLanguageForBaseAttribute(CONS.HEADER_SLUG)
          case 'setCategoryOrderHint': return header.has(CONS.HEADER_CATEGORY_ORDER_HINTS)
          case 'setDescription': return header.has(CONS.HEADER_DESCRIPTION) || header.hasLanguageForBaseAttribute(CONS.HEADER_DESCRIPTION)
          case 'setMetaTitle': return header.has(CONS.HEADER_META_TITLE) || header.hasLanguageForBaseAttribute(CONS.HEADER_META_TITLE)
          case 'setMetaDescription': return header.has(CONS.HEADER_META_DESCRIPTION) || header.hasLanguageForBaseAttribute(CONS.HEADER_META_DESCRIPTION)
          case 'setMetaKeywords': return header.has(CONS.HEADER_META_KEYWORDS) || header.hasLanguageForBaseAttribute(CONS.HEADER_META_KEYWORDS)
          case 'setSearchKeywords': return header.has(CONS.HEADER_SEARCH_KEYWORDS) || header.hasLanguageForBaseAttribute(CONS.HEADER_SEARCH_KEYWORDS)
          case 'addToCategory': case 'removeFromCategory': return header.has(CONS.HEADER_CATEGORIES)
          case 'setTaxCategory': return header.has(CONS.HEADER_TAX)
          case 'setSku': return header.has(CONS.HEADER_SKU)
          case 'setProductVariantKey': return header.has(CONS.HEADER_VARIANT_KEY)
          case 'setKey': return header.has(CONS.HEADER_KEY)
          case 'addVariant': case 'addPrice': case 'removePrice': case 'changePrice': case 'addExternalImage': case 'removeImage': return true
          case 'removeVariant': return this.allowRemovalOfVariants
          default: throw Error(`The action '${action.action}' is not supported. Please contact the commercetools support team!`)
        }
      })

    let allUpdateRequests = filtered.getUpdatePayload()

    // build update request even if there are no update actions
    if (!filtered.shouldUpdate())
      allUpdateRequests = {
        version: existingProduct.version,
        actions: [],
      }


    // check if we should publish product (only if it was not yet published or if there are some changes)
    if (publish && (!existingProduct.published || allUpdateRequests.actions.length))
      allUpdateRequests.actions.push({ action: 'publish' })


    if (this.dryRun)
      if (allUpdateRequests.actions.length) {
        return Promise.resolve(`[row ${rowIndex}] DRY-RUN - updates for ${existingProduct.id}:\n${_.prettify(allUpdateRequests)}`)
      } else {
        return Promise.resolve(`[row ${rowIndex}] DRY-RUN - nothing to update.`)
      }
    else if (allUpdateRequests.actions.length) {
      const chunkifiedUpdateRequests = this.splitUpdateActionsArray(allUpdateRequests, 500)
      return Promise.all(_.map(chunkifiedUpdateRequests, updateRequest => this.client.products.byId(filtered.getUpdateId()).update(updateRequest)))
        .then(result => this.publishProduct(result.body, rowIndex)
          .then(() => Promise.resolve(`[row ${rowIndex}] Product updated.`))).catch((err) => {
          const msg = `[row ${rowIndex}] Problem on updating product:\n${_.prettify(err)}\n${_.prettify(err.body)}`

          if (this.isConcurrentModification(err))
            return Promise.reject('ConcurrentModification')
          else if (this.continueOnProblems)
            return Promise.resolve(`${msg} - ignored!`)
          return Promise.reject(msg)
        })
    }
    return Promise.resolve(`[row ${rowIndex}] Product update not necessary.`)
  }

  create (product, rowIndex, publish) {
    if (publish == null) publish = false
    if (this.dryRun)
      return Promise.resolve(`[row ${rowIndex}] DRY-RUN - create new product.`)
    else if (this.updatesOnly)
      return Promise.resolve(`[row ${rowIndex}] UPDATES ONLY - nothing done.`)
    return this.client.products.create(product)
      .then(result => this.publishProduct(result.body, rowIndex, true, publish)
        .then(() => Promise.resolve(`[row ${rowIndex}] New product created.`))).catch((err) => {
        const msg = `[row ${rowIndex}] Problem on creating new product:\n${_.prettify(err)}\n${_.prettify(err.body)}`
        if (this.continueOnProblems)
          return Promise.resolve(`${msg} - ignored!`)
        return Promise.reject(msg)
      })
  }

  publishProduct (product, rowIndex, publish, publishImmediate) {
    if (publish == null) publish = true
    if (publishImmediate == null) publishImmediate = false
    const action = publish ? 'publish' : 'unpublish'
    if (!this.publishProducts && !publishImmediate)
      return Promise.resolve(`Do not ${action}.`)
    else if (publish && product.published && !product.hasStagedChanges)
      return Promise.resolve(`[row ${rowIndex}] Product is already published - no staged changes.`)

    const data = {
      id: product.id,
      version: product.version,
      actions: [
        { action },
      ],
    }
    return this.client.products.byId(product.id).update(data)
      .then(result => Promise.resolve(`[row ${rowIndex}] Product ${action}ed.`)).catch((err) => {
        if (this.continueOnProblems)
          return Promise.resolve(`[row ${rowIndex}] Product is already ${action}ed.`)
        return Promise.reject(`[row ${rowIndex}] Problem on ${action}ing product:\n${_.prettify(err)}\n${_.prettify(err.body)}`)
      })
  }

  deleteProduct (product, rowIndex) {
    return this.client.products.byId(product.id).delete(product.version)
      .then(() => Promise.resolve(`[row ${rowIndex}] Product deleted.`)).catch(err => Promise.reject(`[row ${rowIndex}] Error on deleting product:\n${_.prettify(err)}\n${_.prettify(err.body)}`))
  }
}

module.exports = Import
