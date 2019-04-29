_ = require 'underscore'
program = require 'commander'
prompt = require 'prompt'
Csv = require 'csv'
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')
util = require('util')
{ProjectCredentialsConfig} = require 'sphere-node-utils'
Importer = require './import'
Exporter = require './export'
CONS = require './constants'
GLOBALS = require './globals'
package_json = require '../package.json'

module.exports = class

  @_list: (val) -> _.map val.split(','), (v) -> v.trim()

  @_getFilterFunction: (opts) ->
    new Promise (resolve, reject) ->
      if opts.csv
        fs.readFileAsync opts.csv, 'utf8'
        .catch (err) ->
          console.error "Problems on reading identity file '#{opts.csv}': #{err}"
          process.exit 2
        .then (content) ->
          Csv().from.string(content)
          .to.array (data, count) ->
            identHeader = data[0][0]
            if identHeader is CONS.HEADER_ID
              productIds = _.flatten _.rest data
              f = (product) -> _.contains productIds, product.id
              resolve f
            else if identHeader is CONS.HEADER_SKU
              skus = _.flatten _.rest data
              f = (product) ->
                product.variants or= []
                variants = [product.masterVariant].concat(product.variants)
                v = _.find variants, (variant) ->
                  _.contains skus, variant.sku
                v?
              resolve f
            else
              reject "CSV does not fit! You only need one column - either '#{CONS.HEADER_ID}' or '#{CONS.HEADER_SKU}'."
#        TODO: you may define a custom attribute to filter on
#        customAttributeName = ''
#        customAttributeType = ''
#        customAttributeValues = []
#        filterFunction = (product) ->
#          product.variants or= []
#          variants = [product.masterVariant].concat(product.variants)
#          _.find variants, (variant) ->
#            variant.attributes or= []
#            _.find variant.attributes, (attribute) ->
#              attribute.name is customAttributeName and
#              # TODO: pass function for getValueOfType
#              value = switch customAttributeType
#                when CONS.ATTRIBUTE_ENUM, CONS.ATTRIBUTE_LENUM then attribute.value.key
#                else attribute.value
#              _.contains customAttributeValues, value

      else
        f = (product) -> true
        resolve f

  @_ensureCredentials: (argv) ->
    if argv.accessToken
      Promise.resolve
        projectKey: argv.projectKey
        accessToken: argv.accessToken
    else if argv.clientId and argv.clientSecret
      Promise.resolve
        projectKey: argv.projectKey
        credentials:
          clientId: argv.clientId
          clientSecret: argv.clientSecret
    else
      ProjectCredentialsConfig.create()
      .then (credentials) ->
        { project_key, client_id, client_secret } = credentials.enrichCredentials
          project_key: argv.projectKey
          client_id: argv.clientId
          client_secret: argv.clientSecret
        Promise.resolve
          projectKey: project_key
          credentials:
            clientId: client_id
            clientSecret: client_secret
  @run: (argv) ->
    
    _consoleWarnAllResults = (result) ->
      # print out full response array by passing util.inspect
      # with maxArrayLength (default is 100)
      console.warn util.inspect(result, { maxArrayLength: null })

    _subCommandHelp = (cmd) ->
      program.emit(cmd, null, ['--help'])
      process.exit 1

    program
      .version package_json.version
      .usage '[globals] [sub-command] [options]'
      .option '-p, --projectKey <key>', 'your SPHERE.IO project-key'
      .option '-i, --clientId <id>', 'your OAuth client id for the SPHERE.IO API'
      .option '-s, --clientSecret <secret>', 'your OAuth client secret for the SPHERE.IO API'
      .option '--accessToken <token>', 'an OAuth access token for the SPHERE.IO API, used instead of clientId and clientSecret'
      .option '--sphereHost <host>', 'SPHERE.IO API host to connect to', 'https://api.commercetools.com'
      .option '--sphereAuthHost <host>', 'SPHERE.IO OAuth host to connect to', 'https://auth.commercetools.com'
      .option '--timeout [millis]', 'Set timeout for requests (default is 300000)', parseInt, 300000
      .option '--verbose', 'give more feedback during action'
      .option '--debug', 'give as many feedback as possible'


    # TODO: validate required options
    program
      .command 'import'
      .description 'Import your products from CSV into your SPHERE.IO project.'
      .option '-c, --csv <file>', 'CSV file containing products to import (alias for "in" parameter)'
      # add alias for csv parameter and "-i" is taken so use "-f" parameter
      .option '-f, --in <file>', 'File containing products to import'
      .option '-z, --zip', 'Input file is archived'
      .option '-x, --xlsx', 'Import from XLSX format'
      .option '-l, --language [lang]', 'Default language to using during import (for slug generation, category linking etc. - default is en)', 'en'
      .option '--csvDelimiter [delim]', 'CSV Delimiter that separates the cells (default is comma - ",")', ','
      .option '--multiValueDelimiter [delim]', 'Delimiter to separate values inside of a cell (default is semicolon - ";")', ';'
      .option '--customAttributesForCreationOnly <items>', 'List of comma-separated attributes to use when creating products (ignore when updating)', @_list
      .option '--continueOnProblems', 'When a product does not validate on the server side (400er response), ignore it and continue with the next products'
      .option '--suppressMissingHeaderWarning', 'Do not show which headers are missing per produt type.'
      .option '--allowRemovalOfVariants', 'If given variants will be removed if there is no corresponding row in the CSV. Otherwise they are not touched.'
      .option '--mergeCategoryOrderHints', 'Merge category order hints instead of replacing them'
      .option '--publish', 'When given, all changes will be published immediately'
      .option '--updatesOnly', "Won't create any new products, only updates existing"
      .option '--dryRun', 'Will list all action that would be triggered, but will not POST them to SPHERE.IO'
      .option '--defaultState [stateKey]', "When given, specifies the key of the state to assign imported products to, if they don't have one"
      .option '-m, --matchBy [value]', 'Product attribute name which will be used to match products. Possible values: id, slug, sku, <custom_attribute_name>. Default: id. Localized attribute types are not supported for <custom_attribute_name> option', 'id'
      .option '-e, --encoding [encoding]', 'Encoding used when reading data from input file | default: utf8', 'utf8'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --csv <file>'
      .action (opts) =>
        GLOBALS.DEFAULT_LANGUAGE = opts.language
        GLOBALS.DELIM_MULTI_VALUE = opts.multiValueDelimiter ? GLOBALS.DELIM_MULTI_VALUE

        return _subCommandHelp('import') unless program.projectKey

        @_ensureCredentials(program)
        .then (authConfig) ->
          options =
            timeout: program.timeout
            show_progress: true
            user_agent: "#{package_json.name} - Import - #{package_json.version}"
            csvDelimiter: opts.csvDelimiter
            encoding: opts.encoding
            importFormat: if opts.xlsx then 'xlsx' else 'csv'
            debug: Boolean(opts.parent.debug)
            mergeCategoryOrderHints: Boolean(opts.mergeCategoryOrderHints)
            authConfig: authConfig
            userAgentConfig:
              libraryName: "#{package_json.name} - Export"
              libraryVersion: "#{package_json.version}"
              contactEmail: 'npmjs@commercetools.com'
            httpConfig:
              host: program.sphereHost
              enableRetry: true
            defaultState: opts.defaultState
          options.authConfig.host = program.sphereAuthHost
          options.continueOnProblems = opts.continueOnProblems or false

          # if program.verbose
          #   options.logConfig.streams = [
          #     {level: 'info', stream: process.stdout}
          #   ]
          # if program.debug
          #   options.logConfig.streams = [
          #     {level: 'debug', stream: process.stdout}
          #   ]

          importer = new Importer options
          importer.blackListedCustomAttributesForUpdate = opts.customAttributesForCreationOnly or []
          importer.suppressMissingHeaderWarning = opts.suppressMissingHeaderWarning
          importer.allowRemovalOfVariants = opts.allowRemovalOfVariants
          importer.publishProducts = opts.publish
          importer.updatesOnly = true if opts.updatesOnly
          importer.defaultState = opts.defaultState
          importer.dryRun = true if opts.dryRun
          importer.matchBy = opts.matchBy

          # params: importManager (filePath, isArchived)
          importer.importManager opts.in || opts.csv, opts.zip
            .then (result) ->
              _consoleWarnAllResults result
              process.exit 0
            .catch (err) ->
              console.error err
              process.exit 1
          .catch (err) ->
            console.error "Problems on reading file '#{opts.csv}': #{err}"
            process.exit 2
        .catch (err) ->
          console.error "Problems on getting client credentials from config files: #{err}"
          _subCommandHelp('import')

    program
      .command 'state'
      .description 'Allows to publish, unpublish or delete (all) products of your SPHERE.IO project.'
      .option '--changeTo <publish,unpublish,delete>', 'publish unpublished products / unpublish published products / delete unpublished products'
      .option '--csv <file>', 'processes products defined in a CSV file by either "sku" or "id". Otherwise all products are processed.'
      .option '-o, --output <file>', 'Path to the file if the product being process is more than the default which is 100.'
      .option '--continueOnProblems', 'When a there is a problem on changing a product\'s state (400er response), ignore it and continue with the next products'
      .option '--forceDelete', 'whether to force deletion without asking for confirmation', false
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --changeTo <state>'
      .action (opts) =>
        return _subCommandHelp('state') unless program.projectKey

        @_ensureCredentials(program)
        .then (authConfig) =>
          options =
            timeout: program.timeout
            show_progress: true
            authConfig: authConfig
            userAgentConfig:
              libraryName: "#{package_json.name} - State"
              libraryVersion: "#{package_json.version}"
              contactEmail: 'npmjs@commercetools.com'
            httpConfig:
              host: program.sphereHost
              enableRetry: true
            # logConfig:
            #   streams: [
            #     {level: 'warn', stream: process.stdout}
            #   ]

          options.authConfig.host = program.sphereAuthHost

          remove = opts.changeTo is 'delete'
          publish = switch opts.changeTo
            when 'publish','delete' then true
            when 'unpublish' then false
            else
              console.error "Unknown argument '#{opts.changeTo}' for option changeTo!"
              process.exit 3

          run = =>
            @_getFilterFunction(opts)
            .then (filterFunction) ->
              importer = new Importer options
              importer.continueOnProblems = opts.continueOnProblems
              importer.changeState(publish, remove, filterFunction)
            .then (result) ->
              if result.length > 100
                fs.writeFileSync opts.output, JSON.stringify(result, null, 2)
              else
                _consoleWarnAllResults result
              process.exit 0
            .catch (err) ->
              if err.stack then console.error(err.stack)
              console.error err
              process.exit 1

          if remove
            if opts.forceDelete
              run options
            else
              prompt.start()
              property =
                name: 'ask'
                message: 'Do you really want to delete products?'
                validator: /y[es]*|n[o]?/
                warning: 'Please answer with yes or no'
                default: 'no'

              prompt.get property, (err, result) ->
                if _.isString(result.ask) and result.ask.match(/y(es){0,1}/i)
                  run options
                else
                  console.error 'Aborted.'
                  process.exit 9
          else
            run options
        .catch (err) ->
          console.error "Problems on getting client credentials from config files: #{err}"
          _subCommandHelp('state')

    program
      .command 'export'
      .description 'Export your products from your SPHERE.IO project to CSV using.'
      .option '-t, --template <file>', 'CSV file containing your header that defines what you want to export'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '-x, --xlsx', 'Export in XLSX format'
      .option '-f, --fullExport', 'Do a full export.'
      .option '-q, --queryString <query>', 'Query string to specify the sub-set of products to export'
      .option '-l, --language [lang]', 'Language used on export for localised attributes (except lenums) and category names (default is en)'
      .option '--queryEncoded', 'Whether the given query string is already encoded or not', false
      .option '--current', 'Will export current product version instead of staged one', false
      .option '--fillAllRows', 'When given product attributes like name will be added to each variant row.'
      .option '--onlyMasterVariants', 'Export only masterVariants from products.', false
      .option '--categoryBy <name>', 'Define which identifier should be used for the categories column - either slug or externalId. If nothing given the named path is used.'
      .option '--categoryOrderHintBy <name>', 'Define which identifier should be used for the categoryOrderHints column - either id or externalId. If nothing given the category id is used.', 'id'
      .option '--filterVariantsByAttributes <query>', 'Query string to filter variants of products'
      .option '--filterPrices <query>', 'Query string to filter prices of products'
      .option '--templateDelimiter <delimiter>', 'Delimiter used in template | default: ,', ","
      .option '--outputDelimiter <delimiter>', 'Delimiter used to separate cells in output file | default: ,', ","
      .option '-e, --encoding [encoding]', 'Encoding used when saving data to output file | default: utf8', 'utf8'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --template <file> --out <file>'
      .action (opts) =>
        if opts.language
          GLOBALS.DEFAULT_LANGUAGE = opts.language

        return _subCommandHelp('export') unless program.projectKey

        @_ensureCredentials(program)
        .then (authConfig) ->
          options =
            encoding: opts.encoding
            exportFormat: if opts.xlsx then 'xlsx' else 'csv'
            outputDelimiter: opts.outputDelimiter
            templateDelimiter: opts.templateDelimiter
            fillAllRows: opts.fillAllRows
            onlyMasterVariants: opts.onlyMasterVariants
            categoryBy: opts.categoryBy
            categoryOrderHintBy: opts.categoryOrderHintBy || 'id'
            debug: Boolean(opts.parent.debug)
            export:
              show_progress: true
              queryString: opts.queryString
              isQueryEncoded: opts.queryEncoded or false
              filterVariantsByAttributes: opts.filterVariantsByAttributes
              filterPrices: opts.filterPrices
            authConfig: authConfig
            userAgentConfig:
              libraryName: "#{package_json.name} - Export"
              libraryVersion: "#{package_json.version}"
              contactEmail: 'npmjs@commercetools.com'
            httpConfig:
              host: program.sphereHost
              enableRetry: true
          options.authConfig.host = program.sphereAuthHost

          exporter = new Exporter options
          (if opts.fullExport then Promise.resolve false
          else if opts.template? then fs.readFileAsync opts.template, 'utf8'
          else new Promise (resolve) ->
            console.warn 'Reading from stdin...'
            chunks = []
            process.stdin.on 'data', (chunk) -> chunks.push chunk
            process.stdin.on 'end', () -> resolve Buffer.concat chunks
          )
          .then (content) ->
            (if content
              exporter.exportDefault(content, opts.out, not opts.current)
            else
              exporter.exportFull(opts.out, not opts.current)
            )
            .then (result) ->
              _consoleWarnAllResults result
              process.exit 0
            .catch (err) ->
              if err.stack then console.error(err.stack)
              console.error err
              process.exit 1
          .catch (err) ->
            console.error "Problems on reading template input: #{err}"
            console.error err
            process.exit 2
        .catch (err) ->
          console.error "Problems on getting client credentials from config files: #{err}"
          _subCommandHelp('export')

    program
      .command 'template'
      .description 'Create a template for a product type of your SPHERE.IO project.'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '--outputDelimiter <delimiter>', 'Delimiter used to separate cells in output file | default: ,', ","
      .option '-l, --languages [lang,lang]', 'List of languages to use for template (default is [en])', @_list, ['en']
      .option '--all', 'Generates one template for all product types - if not given you will be ask which product type to use'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --out <file>'
      .action (opts) =>

        return _subCommandHelp('template') unless program.projectKey

        @_ensureCredentials(program)
        .then (authConfig) ->
          options =
            outputDelimiter: opts.outputDelimiter
            timeout: program.timeout
            show_progress: true
            authConfig: authConfig
            userAgentConfig:
              libraryName: "#{package_json.name} - Template"
              libraryVersion: "#{package_json.version}"
              contactEmail: 'npmjs@commercetools.com'
            httpConfig:
              host: program.sphereHost
              enableRetry: true
            # logConfig:
            #   streams: [
            #     {level: 'warn', stream: process.stdout}
            #   ]
          options.authConfig.host = program.sphereAuthHost
          
          exporter = new Exporter options
          exporter.createTemplate(opts.languages, opts.out, opts.all)
          .then (result) ->
            _consoleWarnAllResults result
            process.exit 0
          .catch (err) ->
            console.error err
            process.exit 1
        .catch (err) ->
          console.error "Problems on getting client credentials from config files: #{err}"
          _subCommandHelp('template')

    program.parse argv
    program.help() if program.args.length is 0

module.exports.run process.argv
