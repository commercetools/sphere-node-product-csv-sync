_ = require 'underscore'
program = require 'commander'
prompt = require 'prompt'
Csv = require 'csv'
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')
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
        config:
          project_key: argv.projectKey
        access_token: argv.accessToken
    else
      ProjectCredentialsConfig.create()
      .then (credentials) ->
        Promise.resolve
          config: credentials.enrichCredentials
            project_key: argv.projectKey
            client_id: argv.clientId
            client_secret: argv.clientSecret

  @run: (argv) ->

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
      .option '--sphereHost <host>', 'SPHERE.IO API host to connect to'
      .option '--sphereProtocol <protocol>', 'SPHERE.IO API protocol to connect to'
      .option '--sphereAuthHost <host>', 'SPHERE.IO OAuth host to connect to'
      .option '--sphereAuthProtocol <protocol>', 'SPHERE.IO OAuth protocol to connect to'
      .option '--timeout [millis]', 'Set timeout for requests (default is 300000)', parseInt, 300000
      .option '--verbose', 'give more feedback during action'
      .option '--debug', 'give as many feedback as possible'


    # TODO: validate required options
    program
      .command 'import'
      .description 'Import your products from CSV into your SPHERE.IO project.'
      .option '-c, --csv <file>', 'CSV file containing products to import'
      .option '-l, --language [lang]', 'Default language to using during import (for slug generation, category linking etc. - default is en)', 'en'
      .option '--csvDelimiter [delim]', 'CSV Delimiter that separates the cells (default is comma - ",")', ','
      .option '--multiValueDelimiter [delim]', 'Delimiter to separate values inside of a cell (default is semicolon - ";")', ';'
      .option '--customAttributesForCreationOnly <items>', 'List of comma-separated attributes to use when creating products (ignore when updating)', @_list
      .option '--continueOnProblems', 'When a product does not validate on the server side (400er response), ignore it and continue with the next products'
      .option '--suppressMissingHeaderWarning', 'Do not show which headers are missing per produt type.'
      .option '--allowRemovalOfVariants', 'If given variants will be removed if there is no corresponding row in the CSV. Otherwise they are not touched.'
      .option '--publish', 'When given, all changes will be published immediately'
      .option '--updatesOnly', "Won't create any new products, only updates existing"
      .option '--dryRun', 'Will list all action that would be triggered, but will not POST them to SPHERE.IO'
      .option '-m, --matchBy [value]', 'Product attribute name which will be used to match products. Possible values: id, slug, sku, <custom_attribute_name>. Default: id. Localized attribute types are not supported for <custom_attribute_name> option', 'id'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --csv <file>'
      .action (opts) =>
        GLOBALS.DEFAULT_LANGUAGE = opts.language
        GLOBALS.DELIM_MULTI_VALUE = opts.multiValueDelimiter ? GLOBALS.DELIM_MULTI_VALUE

        return _subCommandHelp('import') unless program.projectKey

        @_ensureCredentials(program)
        .then (credentials) ->
          options = _.extend credentials,
            timeout: program.timeout
            show_progress: true
            user_agent: "#{package_json.name} - Import - #{package_json.version}"
            # logConfig:
            #   streams: [
            #     {level: 'warn', stream: process.stdout}
            #   ]
            csvDelimiter: opts.csvDelimiter

          options.host = program.sphereHost if program.sphereHost
          options.protocol = program.sphereProtocol if program.sphereProtocol
          if program.sphereAuthHost
            options.oauth_host = program.sphereAuthHost
            options.rejectUnauthorized = false
          options.oauth_protocol = program.sphereAuthProtocol if program.sphereAuthProtocol

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
          importer.validator.suppressMissingHeaderWarning = opts.suppressMissingHeaderWarning
          importer.allowRemovalOfVariants = opts.allowRemovalOfVariants
          importer.publishProducts = opts.publish
          importer.updatesOnly = true if opts.updatesOnly
          importer.dryRun = true if opts.dryRun
          importer.matchBy = opts.matchBy

          (if opts.csv? then fs.readFileAsync opts.csv, 'utf8'
          else new Promise (resolve) ->
            console.warn 'Reading from stdin...'
            chunks = []
            process.stdin.on 'data', (chunk) -> chunks.push chunk
            process.stdin.on 'end', () -> resolve Buffer.concat chunks
          )
          .then (content) ->
            importer.import(content)
            .then (result) ->
              console.warn result
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
        .done()


    program
      .command 'state'
      .description 'Allows to publish, unpublish or delete (all) products of your SPHERE.IO project.'
      .option '--changeTo <publish,unpublish,delete>', 'publish unpublished products / unpublish published products / delete unpublished products'
      .option '--csv <file>', 'processes products defined in a CSV file by either "sku" or "id". Otherwise all products are processed.'
      .option '--continueOnProblems', 'When a there is a problem on changing a product\'s state (400er response), ignore it and continue with the next products'
      .option '--forceDelete', 'whether to force deletion without asking for confirmation', false
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --changeTo <state>'
      .action (opts) =>

        return _subCommandHelp('state') unless program.projectKey

        @_ensureCredentials(program)
        .then (credentials) =>
          options = _.extend credentials,
            timeout: program.timeout
            show_progress: true
            user_agent: "#{package_json.name} - State - #{package_json.version}"
            # logConfig:
            #   streams: [
            #     {level: 'warn', stream: process.stdout}
            #   ]

          options.host = program.sphereHost if program.sphereHost
          options.protocol = program.sphereProtocol if program.sphereProtocol
          if program.sphereAuthHost
            options.oauth_host = program.sphereAuthHost
            options.rejectUnauthorized = false
          options.oauth_protocol = program.sphereAuthProtocol if program.sphereAuthProtocol

          # if program.verbose
          #   options.logConfig.streams = [
          #     {level: 'info', stream: process.stdout}
          #   ]
          # if program.debug
          #   options.logConfig.streams = [
          #     {level: 'debug', stream: process.stdout}
          #   ]

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
              console.warn result
              process.exit 0
            .catch (err) ->
              if err.stack then console.error(err.stack)
              console.error err
              process.exit 1
            .done()

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
        .done()


    program
      .command 'export'
      .description 'Export your products from your SPHERE.IO project to CSV using.'
      .option '-t, --template <file>', 'CSV file containing your header that defines what you want to export'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '-j, --json', 'Export in JSON format'
      .option '-q, --queryString <query>', 'Query string to specify the sub-set of products to export'
      .option '-l, --language [lang]', 'Language used on export for localised attributes (except lenums) and category names (default is en)'
      .option '--queryEncoded', 'Whether the given query string is already encoded or not', false
      .option '--fillAllRows', 'When given product attributes like name will be added to each variant row.'
      .option '--categoryBy <name>', 'Define which identifier should be used to for the categories column - either slug or externalId. If nothing given the named path is used.'
      .option '--filterVariantsByAttributes <query>', 'Query string to filter variants of products'
      .option '--filterPrices <query>', 'Query string to filter prices of products'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --template <file> --out <file>'
      .action (opts) =>
        GLOBALS.DEFAULT_LANGUAGE = opts.language

        return _subCommandHelp('export') unless program.projectKey

        @_ensureCredentials(program)
        .then (credentials) ->
          options =
            fillAllRows: opts.fillAllRows
            categoryBy: opts.categoryBy
            client: _.extend credentials,
              timeout: program.timeout
              user_agent: "#{package_json.name} - Export - #{package_json.version}"
            export:
              show_progress: true
              queryString: opts.queryString
              isQueryEncoded: opts.queryEncoded or false
              filterVariantsByAttributes: opts.filterVariantsByAttributes
              filterPrices: opts.filterPrices
          options.client.host = program.sphereHost if program.sphereHost
          options.client.protocol = program.sphereProtocol if program.sphereProtocol
          if program.sphereAuthHost
            options.client.oauth_host = program.sphereAuthHost
            options.client.rejectUnauthorized = false
          options.client.oauth_protocol = program.sphereAuthProtocol if program.sphereAuthProtocol

          exporter = new Exporter options
          if 'json' in opts
            exporter.exportAsJson(opts.out)
            .then (result) ->
              console.warn result
              process.exit 0
            .catch (err) ->
              if err.stack then console.error(err.stack)
              console.error err
              process.exit 1
            .done()
          else
            (if opts.template? then fs.readFileAsync opts.template, 'utf8'
            else new Promise (resolve) ->
              console.warn 'Reading from stdin...'
              chunks = []
              process.stdin.on 'data', (chunk) -> chunks.push chunk
              process.stdin.on 'end', () -> resolve Buffer.concat chunks
            )
            .then (content) ->
              exporter.export(content, opts.out)
              .then (result) ->
                console.warn result
                process.exit 0
              .catch (err) ->
                if err.stack then console.error(err.stack)
                console.error err
                process.exit 1
            .catch (err) ->
              console.error "Problems on reading template input: #{err}"
              process.exit 2
        .catch (err) ->
          console.error "Problems on getting client credentials from config files: #{err}"
          _subCommandHelp('export')
        .done()

    program
      .command 'template'
      .description 'Create a template for a product type of your SPHERE.IO project.'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '-l, --languages [lang,lang]', 'List of languages to use for template (default is [en])', @_list, ['en']
      .option '--all', 'Generates one template for all product types - if not given you will be ask which product type to use'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --out <file>'
      .action (opts) =>

        return _subCommandHelp('template') unless program.projectKey

        @_ensureCredentials(program)
        .then (credentials) ->
          options =
            client: credentials
            timeout: program.timeout
            show_progress: true
            user_agent: "#{package_json.name} - Template - #{package_json.version}"
            # logConfig:
            #   streams: [
            #     {level: 'warn', stream: process.stdout}
            #   ]

          options.client.host = program.sphereHost if program.sphereHost
          options.client.protocol = program.sphereProtocol if program.sphereProtocol
          if program.sphereAuthHost
            options.client.oauth_host = program.sphereAuthHost
            options.client.rejectUnauthorized = false
          options.client.oauth_protocol = program.sphereAuthProtocol if program.sphereAuthProtocol


          # if program.verbose
          #   options.logConfig.streams = [
          #     {level: 'info', stream: process.stdout}
          #   ]
          # if program.debug
          #   options.logConfig.streams = [
          #     {level: 'debug', stream: process.stdout}
          #   ]

          exporter = new Exporter options
          exporter.createTemplate(opts.languages, opts.out, opts.all)
          .then (result) ->
            console.warn result
            process.exit 0
          .catch (err) ->
            console.error err
            process.exit 1
        .catch (err) ->
          console.error "Problems on getting client credentials from config files: #{err}"
          _subCommandHelp('template')
        .done()

    program.parse argv
    program.help() if program.args.length is 0

module.exports.run process.argv
