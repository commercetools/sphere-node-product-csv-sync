/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS201: Simplify complex destructure assignments
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore')
const Csv = require('csv')
const archiver = require('archiver')
const path = require('path')
const tmp = require('tmp')
const Promise = require('bluebird')
const iconv = require('iconv-lite')
const fs = Promise.promisifyAll(require('fs'))
const prompt = Promise.promisifyAll(require('prompt'))
const { SphereClient } = require('sphere-node-sdk')
const Types = require('./types')
const Categories = require('./categories')
const Channels = require('./channels')
const CustomerGroups = require('./customergroups')
const Header = require('./header')
const Taxes = require('./taxes')
const ExportMapping = require('./exportmapping')
const Writer = require('./io/writer')
const queryStringParser = require('querystring')
const GLOBALS = require('./globals')

// will clean temporary files even when an uncaught exception occurs
tmp.setGracefulCleanup()

// TODO:
// - JSDoc
class Export {
  constructor (options) {
    this._fetchResources = this._fetchResources.bind(this)
    this.exportDefault = this.exportDefault.bind(this)
    this.exportFull = this.exportFull.bind(this)
    this._processChunk = this._processChunk.bind(this)
    this._saveCSV = this._saveCSV.bind(this)
    this._parse = this._parse.bind(this)
    if (options == null) options = {}
    this.options = options
    this.options.outputDelimiter = this.options.outputDelimiter || ','
    this.options.templateDelimiter = this.options.templateDelimiter || ','
    this.options.encoding = this.options.encoding || 'utf8'
    this.options.exportFormat = this.options.exportFormat || 'csv'

    this.queryOptions = {
      queryString: __guard__(this.options.export != null ? this.options.export.queryString : undefined, x => x.trim()),
      isQueryEncoded: (this.options.export != null ? this.options.export.isQueryEncoded : undefined),
      filterVariantsByAttributes: this._parseQuery(this.options.export != null ? this.options.export.filterVariantsByAttributes
        : undefined),
      filterPrices: this._parseQuery(this.options.export != null ? this.options.export.filterPrices : undefined),
    }

    this.client = new SphereClient(this.options.client)

    // TODO: using single mapping util instead of services
    this.typesService = new Types()
    this.categoryService = new Categories()
    this.channelService = new Channels()
    this.customerGroupService = new CustomerGroups()
    this.taxService = new Taxes()

    this.createdFiles = {}
  }

  _parseQuery (queryStr) {
    if (!queryStr) return null
    return _.map(
      queryStr.split('&'),
      (filter) => {
        filter = filter.split('=')
        if ((filter[1] === 'true') || (filter[1] === 'false'))
          filter[1] = filter[1] === 'true'

        return {
          name: filter[0],
          value: filter[1],
        }
      },
    )
  }

  _filterPrices (prices, filters) {
    return _.filter(prices, price =>
      _.reduce(
        filters,
        (filterOutPrice, filter) => filterOutPrice && (price[filter.name] === filter.value)
        , true,
      ))
  }

  _filterVariantsByAttributes (variants, filter) {
    const filteredVariants = _.filter(variants, (variant) => {
      if ((filter != null ? filter.length : undefined) > 0)
        return _.reduce(
          filter,
          (filterOutVariant, filter) => {
            // filter attributes
            const attribute = _.findWhere(variant.attributes, {
              name: filter.name,
            })
            return filterOutVariant && !!attribute &&
              (attribute.value === filter.value)
          }
          , true,
        )

      return true
    })

    // filter prices of filtered variants
    return _.map(filteredVariants, (variant) => {
      if ((this.queryOptions.filterPrices != null ? this.queryOptions.filterPrices.length : undefined) > 0) {
        variant.prices = this._filterPrices(
          variant.prices,
          this.queryOptions.filterPrices,
        )
        if (variant.prices.length === 0) return null
      }
      return variant
    })
  }

  _initMapping (header) {
    _.extend(this.options, {
      channelService: this.channelService,
      categoryService: this.categoryService,
      typesService: this.typesService,
      customerGroupService: this.customerGroupService,
      taxService: this.taxService,
      header,
    })
    return new ExportMapping(this.options)
  }

  _parseQueryString (query) {
    return queryStringParser.parse(query)
  }

  _appendQueryStringPredicate (query, predicate) {
    query.where = query.where ? `${query.where} AND ${predicate}` : predicate
    return query
  }

  _stringifyQueryString (query) {
    return decodeURIComponent(queryStringParser.stringify(query))
  }

  // return the correct product service in case query string is used or not
  _getProductService (staged, customWherePredicate) {
    if (staged == null) staged = true
    if (customWherePredicate == null) customWherePredicate = false
    const productsService = this.client.productProjections
    const perPage = 100

    if (this.queryOptions.queryString) {
      let query = this._parseQueryString(this.queryOptions.queryString)

      if (customWherePredicate)
        query = this._appendQueryStringPredicate(query, customWherePredicate)


      productsService.byQueryString(this._stringifyQueryString(query), false)
      return productsService
    }
    productsService.where(customWherePredicate || '')
    return productsService.all().perPage(perPage).staged(staged)
  }

  _fetchResources () {
    const data = [
      this.typesService.getAll(this.client),
      this.categoryService.getAll(this.client),
      this.channelService.getAll(this.client),
      this.customerGroupService.getAll(this.client),
      this.taxService.getAll(this.client),
    ]
    return Promise.all(data)
      .then((...args) => {
        const [productTypes, categories, channels, customerGroups, taxes] = Array.from(args[0])
        this.typesService.buildMaps(productTypes.body.results)
        this.categoryService.buildMaps(categories.body.results)
        this.channelService.buildMaps(channels.body.results)
        this.customerGroupService.buildMaps(customerGroups.body.results)
        this.taxService.buildMaps(taxes.body.results)

        console.warn(`Fetched ${productTypes.body.total} product type(s).`)
        return Promise.resolve({
          productTypes, categories, channels, customerGroups, taxes,
        })
      })
  }

  exportDefault (templateContent, outputFile, staged) {
    if (staged == null) staged = true
    return this._fetchResources()
      .then(({ productTypes }) => this.export(templateContent, outputFile, productTypes, staged, false, true))
  }

  _archiveFolder (inputFolder, outputFile) {
    const output = fs.createWriteStream(outputFile)
    const archive = archiver('zip')

    return new Promise(((resolve, reject) => {
      output.on('close', () => resolve())
      archive.on('error', err => reject(err))
      archive.pipe(output)

      archive.bulk([
        {
          expand: true, cwd: inputFolder, src: ['**'], dest: 'products',
        },
      ])
      return archive.finalize()
    }))
  }

  exportFull (output, staged) {
    if (staged == null) staged = true
    const lang = GLOBALS.DEFAULT_LANGUAGE
    console.log('Creating full export for "%s" language', lang)

    return this._fetchResources()
      .then(({ productTypes }) => {
        if (!productTypes.body.results.length)
          return Promise.reject('Project does not have any productTypes.')


        const tempDir = tmp.dirSync({ unsafeCleanup: true })
        console.log('Creating temp directory in %s', tempDir.name)

        return Promise.map(
          productTypes.body.results, (type) => {
            console.log('Processing products with productType "%s"', type.name)
            const csv = new ExportMapping().createTemplate(type, [lang])
            const fileName = `${_.slugify(type.name)}_${type.id}.${this.options.exportFormat}`
            const filePath = path.join(tempDir.name, fileName)
            const condition = `productType(id="${type.id}")`

            return this.export(csv.join(this.options.templateDelimiter), filePath, productTypes, staged, condition, false)
          }
          , { concurrency: 1 },
        )
          .then(() => {
            console.log('All productTypes were processed - archiving output folder')
            return this._archiveFolder(tempDir.name, output)
          }).then(() => {
            console.log('Folder was archived and saved to %s', output)
            tempDir.removeCallback()
            return Promise.resolve('Export done.')
          })
      })
  }

  _processChunk (writer, products, productTypes, createFileWhenEmpty, header, exportMapper, outputFile) {
    let data = []
    // if there are no products to export
    if (!products.length && !createFileWhenEmpty)
      return Promise.resolve()


    return ((() => {
      if (this.createdFiles[outputFile])
        return Promise.resolve()

      this.createdFiles[outputFile] = 1
      return writer.setHeader(header.rawHeader)
    })())
      .then(() => {
        _.each(products, (product) => {
        // filter variants
          product.variants = this._filterVariantsByAttributes(
            product.variants,
            this.queryOptions.filterVariantsByAttributes,
          );
          // filter masterVariant
          [ product.masterVariant ] = Array.from(this._filterVariantsByAttributes(
            [ product.masterVariant ],
            this.queryOptions.filterVariantsByAttributes,
          ))
          // remove all the variants that don't meet the price condition
          product.variants = _.compact(product.variants)
          return data = data.concat(exportMapper.mapProduct(
            product,
            productTypes.body.results,
          ))
        })
        return writer.write(data)
      }).catch((err) => {
        console.log('Error while processing products batch', err)
        return Promise.reject(err)
      })
  }

  export (templateContent, outputFile, productTypes, staged, customWherePredicate, createFileWhenEmpty) {
    if (staged == null) staged = true
    if (customWherePredicate == null) customWherePredicate = false
    if (createFileWhenEmpty == null) createFileWhenEmpty = false
    return this._parse(templateContent)
      .then((header) => {
        let writer = null
        const errors = header.validate()
        let rowsReaded = 0

        if (_.size(errors) !== 0)
          return Promise.reject(errors)

        header.toIndex()
        header.toLanguageIndex()
        const exportMapper = this._initMapping(header)

        _.each(productTypes.body.results, productType => header._productTypeLanguageIndexes(productType))

        return this._getProductService(staged, customWherePredicate)
          .process(
            (res) => {
              rowsReaded += res.body.count
              console.warn(`Fetched ${res.body.count} product(s).`)

              // init writer and create output file
              // when doing full export - don't create empty files
              if (!writer && (createFileWhenEmpty || rowsReaded))
                try {
                  writer = new Writer({
                    csvDelimiter: this.options.outputDelimiter,
                    encoding: this.options.encoding,
                    exportFormat: this.options.exportFormat,
                    outputFile,
                    debug: this.options.debug,
                  })
                } catch (e) {
                  return Promise.reject(e)
                }


              return this._processChunk(writer, res.body.results, productTypes, createFileWhenEmpty, header, exportMapper, outputFile)
            }
            , { accumulate: false },
          )
          .then(() => {
            if (createFileWhenEmpty || rowsReaded)
              return writer.flush()

            return Promise.resolve()
          }).then(() => Promise.resolve('Export done.'))
          .catch((err) => {
            console.dir(err, { depth: 10 })
            return Promise.reject(err)
          })
      })
  }

  createTemplate (languages, outputFile, allProductTypes) {
    if (allProductTypes == null) allProductTypes = false
    return this.typesService.getAll(this.client)
      .then((result) => {
        const productTypes = result.body.results
        if (_.size(productTypes) === 0)
          return Promise.reject('Can not find any product type.')

        let csv
        const idsAndNames = _.map(productTypes, productType => productType.name)

        if (allProductTypes) {
          let allHeaders = []
          const exportMapping = new ExportMapping()
          _.each(productTypes, productType => allHeaders = allHeaders.concat(exportMapping.createTemplate(productType, languages)))
          csv = _.uniq(allHeaders)
          return this._saveCSV(outputFile, [csv])
            .then(() => Promise.resolve('Template for all product types generated.'))
        }
        _.each(idsAndNames, (entry, index) => console.warn('  %d) %s', index, entry))
        prompt.start()
        const property = {
          name: 'number',
          message: 'Enter the number of the producttype.',
          validator: /\d+/,
          warning: 'Please enter a valid number',
        }
        return prompt.getAsync(property)
          .then((result) => {
            const productType = productTypes[parseInt(result.number)]
            if (productType) {
              console.warn(`Generating template for product type '${productType.name}' (id: ${productType.id}).`)
              process.stdin.destroy()
              csv = new ExportMapping().createTemplate(productType, languages)
              return this._saveCSV(outputFile, [csv])
                .then(() => Promise.resolve('Template generated.'))
            } return Promise.reject('Please re-run and select a valid number.')
          })
      })
  }

  _saveCSV (file, content, append) {
    const flag = append ? 'a' : 'w'
    return new Promise((resolve, reject) => {
      const parsedCsv = Csv().from(content, { delimiter: this.options.outputDelimiter })
      const opts =
        { flag }

      if (file)
        parsedCsv.to.string((res) => {
          const converted = iconv.encode(`${res}\n`, this.options.encoding)
          return fs.writeFileAsync(file, converted, opts)
            .then(() => resolve())
            .catch(err => reject(err))
        })
      else
        parsedCsv.to.stream(process.stdout, opts)


      return parsedCsv
        .on('error', err => reject(err))
        .on('close', count => resolve(count))
    })
  }

  _parse (csvString) {
    return new Promise((resolve, reject) => {
      csvString = _.trim(csvString, this.options.templateDelimiter)
      return Csv().from.string(csvString, { delimiter: this.options.templateDelimiter })
        .to.array((data, count) => {
          const header = new Header(data[0])
          return resolve(header)
        }).on('error', err => reject(err))
    })
  }
}

module.exports = Export
function __guard__ (value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined
}
