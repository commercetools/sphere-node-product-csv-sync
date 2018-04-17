/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore')
const program = require('commander')
const prompt = require('prompt')
const Csv = require('csv')
const Promise = require('bluebird')
const fs = Promise.promisifyAll(require('fs'))
const { ProjectCredentialsConfig } = require('sphere-node-utils')
const Importer = require('./import')
const Exporter = require('./export')
const CONS = require('./constants')
const GLOBALS = require('./globals')
const package_json = require('../package.json')

module.exports = class {
  static _list (val) { return _.map(val.split(','), v => v.trim()) }

  static _getFilterFunction (opts) {
    return new Promise(((resolve, reject) => {
      if (opts.csv)
        return fs.readFileAsync(opts.csv, 'utf8')
          .catch((err) => {
            console.error(`Problems on reading identity file '${opts.csv}': ${err}`)
            return process.exit(2)
          }).then(content =>
            Csv().from.string(content)
              .to.array((data, count) => {
                let f
                const identHeader = data[0][0]
                if (identHeader === CONS.HEADER_ID) {
                  const productIds = _.flatten(_.rest(data))
                  f = product => _.contains(productIds, product.id)
                  return resolve(f)
                } else if (identHeader === CONS.HEADER_SKU) {
                  const skus = _.flatten(_.rest(data))
                  f = function (product) {
                    if (!product.variants) product.variants = []
                    const variants = [product.masterVariant].concat(product.variants)
                    const v = _.find(variants, variant => _.contains(skus, variant.sku))
                    return (v != null)
                  }
                  return resolve(f)
                }
                return reject(`CSV does not fit! You only need one column - either '${CONS.HEADER_ID}' or '${CONS.HEADER_SKU}'.`)
              }))
      //        TODO: you may define a custom attribute to filter on
      //        customAttributeName = ''
      //        customAttributeType = ''
      //        customAttributeValues = []
      //        filterFunction = (product) ->
      //          product.variants or= []
      //          variants = [product.masterVariant].concat(product.variants)
      //          _.find variants, (variant) ->
      //            variant.attributes or= []
      //            _.find variant.attributes, (attribute) ->
      //              attribute.name is customAttributeName and
      //              # TODO: pass function for getValueOfType
      //              value = switch customAttributeType
      //                when CONS.ATTRIBUTE_ENUM, CONS.ATTRIBUTE_LENUM then attribute.value.key
      //                else attribute.value
      //              _.contains customAttributeValues, value


      const f = product => true
      return resolve(f)
    }))
  }

  static _ensureCredentials (argv) {
    if (argv.accessToken)
      return Promise.resolve({
        config: {
          project_key: argv.projectKey,
        },
        access_token: argv.accessToken,
      })
    return ProjectCredentialsConfig.create()
      .then(credentials =>
        Promise.resolve({
          config: credentials.enrichCredentials({
            project_key: argv.projectKey,
            client_id: argv.clientId,
            client_secret: argv.clientSecret,
          }),
        }))
  }

  static run (argv) {
    const _subCommandHelp = function (cmd) {
      program.emit(cmd, null, ['--help'])
      return process.exit(1)
    }

    program
      .version(package_json.version)
      .usage('[globals] [sub-command] [options]')
      .option('-p, --projectKey <key>', 'your SPHERE.IO project-key')
      .option('-i, --clientId <id>', 'your OAuth client id for the SPHERE.IO API')
      .option('-s, --clientSecret <secret>', 'your OAuth client secret for the SPHERE.IO API')
      .option('--accessToken <token>', 'an OAuth access token for the SPHERE.IO API, used instead of clientId and clientSecret')
      .option('--sphereHost <host>', 'SPHERE.IO API host to connect to')
      .option('--sphereProtocol <protocol>', 'SPHERE.IO API protocol to connect to')
      .option('--sphereAuthHost <host>', 'SPHERE.IO OAuth host to connect to')
      .option('--sphereAuthProtocol <protocol>', 'SPHERE.IO OAuth protocol to connect to')
      .option('--timeout [millis]', 'Set timeout for requests (default is 300000)', parseInt, 300000)
      .option('--verbose', 'give more feedback during action')
      .option('--debug', 'give as many feedback as possible')


    // TODO: validate required options
    program
      .command('import')
      .description('Import your products from CSV into your SPHERE.IO project.')
      .option('-c, --csv <file>', 'CSV file containing products to import (alias for "in" parameter)')
      // add alias for csv parameter and "-i" is taken so use "-f" parameter
      .option('-f, --in <file>', 'File containing products to import')
      .option('-z, --zip', 'Input file is archived')
      .option('-x, --xlsx', 'Import from XLSX format')
      .option('-l, --language [lang]', 'Default language to using during import (for slug generation, category linking etc. - default is en)', 'en')
      .option('--csvDelimiter [delim]', 'CSV Delimiter that separates the cells (default is comma - ",")', ',')
      .option('--multiValueDelimiter [delim]', 'Delimiter to separate values inside of a cell (default is semicolon - ";")', ';')
      .option('--customAttributesForCreationOnly <items>', 'List of comma-separated attributes to use when creating products (ignore when updating)', this._list)
      .option('--continueOnProblems', 'When a product does not validate on the server side (400er response), ignore it and continue with the next products')
      .option('--suppressMissingHeaderWarning', 'Do not show which headers are missing per produt type.')
      .option('--allowRemovalOfVariants', 'If given variants will be removed if there is no corresponding row in the CSV. Otherwise they are not touched.')
      .option('--mergeCategoryOrderHints', 'Merge category order hints instead of replacing them')
      .option('--publish', 'When given, all changes will be published immediately')
      .option('--updatesOnly', 'Won\'t create any new products, only updates existing')
      .option('--dryRun', 'Will list all action that would be triggered, but will not POST them to SPHERE.IO')
      .option('-m, --matchBy [value]', 'Product attribute name which will be used to match products. Possible values: id, slug, sku, <custom_attribute_name>. Default: id. Localized attribute types are not supported for <custom_attribute_name> option', 'id')
      .option('-e, --encoding [encoding]', 'Encoding used when reading data from input file | default: utf8', 'utf8')
      .usage('--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --csv <file>')
      .action((opts) => {
        GLOBALS.DEFAULT_LANGUAGE = opts.language
        GLOBALS.DELIM_MULTI_VALUE = opts.multiValueDelimiter != null ? opts.multiValueDelimiter : GLOBALS.DELIM_MULTI_VALUE

        if (!program.projectKey) return _subCommandHelp('import')

        return this._ensureCredentials(program)
          .then((credentials) => {
            const options = _.extend(credentials, {
              timeout: program.timeout,
              show_progress: true,
              user_agent: `${package_json.name} - Import - ${package_json.version}`,
              csvDelimiter: opts.csvDelimiter,
              encoding: opts.encoding,
              importFormat: opts.xlsx ? 'xlsx' : 'csv',
              debug: Boolean(opts.parent.debug),
              mergeCategoryOrderHints: Boolean(opts.mergeCategoryOrderHints),
            })

            if (program.sphereHost) options.host = program.sphereHost
            if (program.sphereProtocol) options.protocol = program.sphereProtocol
            if (program.sphereAuthHost) {
              options.oauth_host = program.sphereAuthHost
              options.rejectUnauthorized = false
            }
            if (program.sphereAuthProtocol) options.oauth_protocol = program.sphereAuthProtocol

            options.continueOnProblems = opts.continueOnProblems || false

            // if program.verbose
            //   options.logConfig.streams = [
            //     {level: 'info', stream: process.stdout}
            //   ]
            // if program.debug
            //   options.logConfig.streams = [
            //     {level: 'debug', stream: process.stdout}
            //   ]

            const importer = new Importer(options)
            importer.blackListedCustomAttributesForUpdate = opts.customAttributesForCreationOnly || []
            importer.suppressMissingHeaderWarning = opts.suppressMissingHeaderWarning
            importer.allowRemovalOfVariants = opts.allowRemovalOfVariants
            importer.publishProducts = opts.publish
            if (opts.updatesOnly) importer.updatesOnly = true
            if (opts.dryRun) importer.dryRun = true
            importer.matchBy = opts.matchBy

            // params: importManager (filePath, isArchived)
            return importer.importManager(opts.in || opts.csv, opts.zip)
              .then((result) => {
                console.warn(result)
                return process.exit(0)
              }).catch((err) => {
                console.error(err)
                return process.exit(1)
              }).catch((err) => {
                console.error(`Problems on reading file '${opts.csv}': ${err}`)
                return process.exit(2)
              })
          }).catch((err) => {
            console.error(`Problems on getting client credentials from config files: ${err}`)
            return _subCommandHelp('import')
          }).done()
      })


    program
      .command('state')
      .description('Allows to publish, unpublish or delete (all) products of your SPHERE.IO project.')
      .option('--changeTo <publish,unpublish,delete>', 'publish unpublished products / unpublish published products / delete unpublished products')
      .option('--csv <file>', 'processes products defined in a CSV file by either "sku" or "id". Otherwise all products are processed.')
      .option('--continueOnProblems', 'When a there is a problem on changing a product\'s state (400er response), ignore it and continue with the next products')
      .option('--forceDelete', 'whether to force deletion without asking for confirmation', false)
      .usage('--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --changeTo <state>')
      .action((opts) => {
        if (!program.projectKey) return _subCommandHelp('state')

        return this._ensureCredentials(program)
          .then((credentials) => {
            const options = _.extend(credentials, {
              timeout: program.timeout,
              show_progress: true,
              user_agent: `${package_json.name} - State - ${package_json.version}`,
            })
            // logConfig:
            //   streams: [
            //     {level: 'warn', stream: process.stdout}
            //   ]

            if (program.sphereHost) options.host = program.sphereHost
            if (program.sphereProtocol) options.protocol = program.sphereProtocol
            if (program.sphereAuthHost) {
              options.oauth_host = program.sphereAuthHost
              options.rejectUnauthorized = false
            }
            if (program.sphereAuthProtocol) options.oauth_protocol = program.sphereAuthProtocol

            // if program.verbose
            //   options.logConfig.streams = [
            //     {level: 'info', stream: process.stdout}
            //   ]
            // if program.debug
            //   options.logConfig.streams = [
            //     {level: 'debug', stream: process.stdout}
            //   ]

            const remove = opts.changeTo === 'delete'
            const publish = (() => {
              switch (opts.changeTo) {
                case 'publish': case 'delete': return true
                case 'unpublish': return false
                default:
                  console.error(`Unknown argument '${opts.changeTo}' for option changeTo!`)
                  return process.exit(3)
              }
            })()

            const run = () => this._getFilterFunction(opts)
              .then((filterFunction) => {
                const importer = new Importer(options)
                importer.continueOnProblems = opts.continueOnProblems
                return importer.changeState(publish, remove, filterFunction)
              }).then((result) => {
                console.warn(result)
                return process.exit(0)
              }).catch((err) => {
                if (err.stack) console.error(err.stack)
                console.error(err)
                return process.exit(1)
              })
              .done()

            if (remove)
              if (opts.forceDelete) {
                return run(options)
              } else {
                prompt.start()
                const property = {
                  name: 'ask',
                  message: 'Do you really want to delete products?',
                  validator: /y[es]*|n[o]?/,
                  warning: 'Please answer with yes or no',
                  default: 'no',
                }

                return prompt.get(property, (err, result) => {
                  if (_.isString(result.ask) && result.ask.match(/y(es){0,1}/i))
                    return run(options)

                  console.error('Aborted.')
                  return process.exit(9)
                })
              }
            return run(options)
          }).catch((err) => {
            console.error(`Problems on getting client credentials from config files: ${err}`)
            return _subCommandHelp('state')
          }).done()
      })

    program
      .command('export')
      .description('Export your products from your SPHERE.IO project to CSV using.')
      .option('-t, --template <file>', 'CSV file containing your header that defines what you want to export')
      .option('-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in')
      .option('-x, --xlsx', 'Export in XLSX format')
      .option('-f, --fullExport', 'Do a full export.')
      .option('-q, --queryString <query>', 'Query string to specify the sub-set of products to export')
      .option('-l, --language [lang]', 'Language used on export for localised attributes (except lenums) and category names (default is en)')
      .option('--queryEncoded', 'Whether the given query string is already encoded or not', false)
      .option('--fillAllRows', 'When given product attributes like name will be added to each variant row.')
      .option('--categoryBy <name>', 'Define which identifier should be used for the categories column - either slug or externalId. If nothing given the named path is used.')
      .option('--categoryOrderHintBy <name>', 'Define which identifier should be used for the categoryOrderHints column - either id or externalId. If nothing given the category id is used.', 'id')
      .option('--filterVariantsByAttributes <query>', 'Query string to filter variants of products')
      .option('--filterPrices <query>', 'Query string to filter prices of products')
      .option('--templateDelimiter <delimiter>', 'Delimiter used in template | default: ,', ',')
      .option('--outputDelimiter <delimiter>', 'Delimiter used to separate cells in output file | default: ,', ',')
      .option('-e, --encoding [encoding]', 'Encoding used when saving data to output file | default: utf8', 'utf8')
      .usage('--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --template <file> --out <file>')
      .action((opts) => {
        if (opts.language)
          GLOBALS.DEFAULT_LANGUAGE = opts.language


        if (!program.projectKey) return _subCommandHelp('export')

        return this._ensureCredentials(program)
          .then((credentials) => {
            const options = {
              encoding: opts.encoding,
              exportFormat: opts.xlsx ? 'xlsx' : 'csv',
              outputDelimiter: opts.outputDelimiter,
              templateDelimiter: opts.templateDelimiter,
              fillAllRows: opts.fillAllRows,
              categoryBy: opts.categoryBy,
              categoryOrderHintBy: opts.categoryOrderHintBy || 'id',
              debug: Boolean(opts.parent.debug),
              client: _.extend(credentials, {
                timeout: program.timeout,
                user_agent: `${package_json.name} - Export - ${package_json.version}`,
              }),
              export: {
                show_progress: true,
                queryString: opts.queryString,
                isQueryEncoded: opts.queryEncoded || false,
                filterVariantsByAttributes: opts.filterVariantsByAttributes,
                filterPrices: opts.filterPrices,
              },
            }
            if (program.sphereHost) options.client.host = program.sphereHost
            if (program.sphereProtocol) options.client.protocol = program.sphereProtocol
            if (program.sphereAuthHost) {
              options.client.oauth_host = program.sphereAuthHost
              options.client.rejectUnauthorized = false
            }
            if (program.sphereAuthProtocol) options.client.oauth_protocol = program.sphereAuthProtocol

            const exporter = new Exporter(options)
            return (opts.fullExport ? Promise.resolve(false)
              : (opts.template != null) ? fs.readFileAsync(opts.template, 'utf8')
                : new Promise(((resolve) => {
                  console.warn('Reading from stdin...')
                  const chunks = []
                  process.stdin.on('data', chunk => chunks.push(chunk))
                  return process.stdin.on('end', () => resolve(Buffer.concat(chunks)))
                })))
              .then(content =>
                (content ?
                  exporter.exportDefault(content, opts.out)
                  :
                  exporter.exportFull(opts.out)
                )
                  .then((result) => {
                    console.warn(result)
                    return process.exit(0)
                  }).catch((err) => {
                    if (err.stack) console.error(err.stack)
                    console.error(err)
                    return process.exit(1)
                  })).catch((err) => {
                console.error(`Problems on reading template input: ${err}`)
                return process.exit(2)
              })
          }).catch((err) => {
            console.error(`Problems on getting client credentials from config files: ${err}`)
            return _subCommandHelp('export')
          }).done()
      })

    program
      .command('template')
      .description('Create a template for a product type of your SPHERE.IO project.')
      .option('-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in')
      .option('--outputDelimiter <delimiter>', 'Delimiter used to separate cells in output file | default: ,', ',')
      .option('-l, --languages [lang,lang]', 'List of languages to use for template (default is [en])', this._list, ['en'])
      .option('--all', 'Generates one template for all product types - if not given you will be ask which product type to use')
      .usage('--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --out <file>')
      .action((opts) => {
        if (!program.projectKey) return _subCommandHelp('template')

        return this._ensureCredentials(program)
          .then((credentials) => {
            const options = {
              outputDelimiter: opts.outputDelimiter,
              client: credentials,
              timeout: program.timeout,
              show_progress: true,
              user_agent: `${package_json.name} - Template - ${package_json.version}`,
            }
            // logConfig:
            //   streams: [
            //     {level: 'warn', stream: process.stdout}
            //   ]

            if (program.sphereHost) options.client.host = program.sphereHost
            if (program.sphereProtocol) options.client.protocol = program.sphereProtocol
            if (program.sphereAuthHost) {
              options.client.oauth_host = program.sphereAuthHost
              options.client.rejectUnauthorized = false
            }
            if (program.sphereAuthProtocol) options.client.oauth_protocol = program.sphereAuthProtocol


            // if program.verbose
            //   options.logConfig.streams = [
            //     {level: 'info', stream: process.stdout}
            //   ]
            // if program.debug
            //   options.logConfig.streams = [
            //     {level: 'debug', stream: process.stdout}
            //   ]

            const exporter = new Exporter(options)
            return exporter.createTemplate(opts.languages, opts.out, opts.all)
              .then((result) => {
                console.warn(result)
                return process.exit(0)
              }).catch((err) => {
                console.error(err)
                return process.exit(1)
              })
          }).catch((err) => {
            console.error(`Problems on getting client credentials from config files: ${err}`)
            return _subCommandHelp('template')
          }).done()
      })

    program.parse(argv)
    if (program.args.length === 0) return program.help()
  }
}

module.exports.run(process.argv)
