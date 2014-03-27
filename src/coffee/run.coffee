Importer = require '../lib/import'
Exporter = require '../lib/export'
Variants = require '../lib/variants'
package_json = require '../package.json'
CONS = require '../lib/constants'
fs = require 'fs'
Q = require 'q'
program = require 'commander'
prompt = require 'prompt'

Csv = require 'csv'
_ = require('underscore')._

module.exports = class

  @_list: (val) -> val.split ','

  @_getFilterFunction: (opts) ->
    deferred = Q.defer()
    if opts.csv
      fs.readFile opts.csv, 'utf8', (err, content) ->
        if err
          console.error "Problems on reading identity file '#{opts.csv}': " + err
          process.exit 2
        Csv().from.string(content).to.array (data, count) ->
          identHeader = data[0][0]
          if identHeader is CONS.HEADER_ID
            productIds = _.flatten _.rest data
            f = (product) ->
              _.contains productIds, product.id
            deferred.resolve f
          else if identHeader is CONS.HEADER_SKU
            skus = _.flatten _.rest data
            f = (product) ->
              product.variants or= []
              variants = [product.masterVariant].concat(product.variants)
              v = _.find variants, (variant) ->
                _.contains skus, variant.sku
              v?
            deferred.resolve f
          else
            deferred.reject "CSV does not fit! You only need one column - either '#{CONS.HEADER_ID}' or '#{CONS.HEADER_SKU}'."

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
      deferred.resolve f

    deferred.promise

  @run: (argv) ->
    program
      .version package_json.version
      .usage '[globals] [sub-command] [options]'
      .option '-p, --projectKey <key>', 'your SPHERE.IO project-key'
      .option '-i, --clientId <id>', 'your OAuth client id for the SPHERE.IO API'
      .option '-s, --clientSecret <secret>', 'your OAuth client secret for the SPHERE.IO API'
      .option '--timeout [millis]', 'Set timeout for requests', parseInt, 300000
      .option '--verbose', 'give more feedback during action'
      .option '--debug', 'give as many feedback as possible'

    program
      .command 'import'
      .description 'Import your products from CSV into your SPHERE.IO project.'
      .option '-c, --csv <file>', 'CSV file containing products to import'
      .option '-l, --language [lang]', 'Default language to using during import (for slug generation, category linking etc.)', 'en'
      .option '--continueOnProblems', 'When a product does not validate on the server side (400er response), ignore it and continue with the next products'
      .option '--publish', 'When given, all changes will be published immediately'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --csv <file>'
      .action (opts) ->
        CONS.DEFAULT_LANGUAGE = opts.language

        options =
          config:
            project_key: program.projectKey
            client_id: program.clientId
            client_secret: program.clientSecret
          timeout: program.timeout
          show_progress: true
          user_agent: "#{package_json.name} - Import - #{package_json.version}"
          logConfig:
            levelStream: 'warn'
            levelFile: 'warn'
        if program.verbose
          options.logConfig.levelStream = 'info'
        if program.debug
          options.logConfig.levelStream = 'debug'

        importer = new Importer options
        importer.publishProducts = opts.publish
        importer.continueOnProblems = opts.continueOnProblems

        fs.readFile opts.csv, 'utf8', (err, content) ->
          if err
            console.error "Problems on reading file '#{opts.csv}': " + err
            process.exit 2

          importer.import content, (result) ->
            if result.status
              console.log result.message
              process.exit 0
            console.error result.message
            process.exit 1

    program
      .command 'state'
      .description 'Allows to publish, unpublish or delete (all) products of your SPHERE.IO project.'
      .option '--changeTo <publish,unpublish,delete>', 'publish unpublished products / unpublish published products / delete unpublished products'
      .option '--csv <file>', 'processes products defined in a CSV file by either "sku" or "id". Otherwise all products are processed.'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --changeTo <state>'
      .action (opts) =>

        options =
          config:
            project_key: program.projectKey
            client_id: program.clientId
            client_secret: program.clientSecret
          timeout: program.timeout
          show_progress: true
          user_agent: "#{package_json.name} - Publish - #{package_json.version}"
          logConfig:
            levelStream: 'warn'
            levelFile: 'warn'
        if program.verbose
          options.logConfig = 'info'
        if program.debug
          options.logConfig = 'debug'

        remove = opts.changeTo is 'delete'
        publish = switch opts.changeTo
          when 'publish','delete' then true
          when 'unpublish' then false
          else
            console.error "Unknown argument '#{opts.changeTo}' for option changeTo!"
            process.exit 2

        run = =>
          @_getFilterFunction(opts).then (filterFunction) ->
            importer = new Importer options
            importer.changeState publish, remove, filterFunction, (result) ->
              if result.status
                console.log result.message
                process.exit 0
              console.error result.message
              process.exit 1
          .fail (msg) ->
            console.error msg
            process.exit 3

        if remove
          prompt.start()
          property =
            name: 'ask'
            message: 'Do you really want to delete products?'
            validator: /y[es]*|n[o]?/
            warning: 'Please answer with yes or no'
            default: 'no'

          prompt.get property, (err, result) ->
            if result.ask
              run()
            else
              console.log 'Cancelled.'
              process.exit 9
        else
          run()

    program
      .command 'export'
      .description 'Export your products from your SPHERE.IO project to CSV using.'
      .option '-t, --template <file>', 'CSV file containing your header that defines what you want to export'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '-j, --json <file>', 'Path to the JSON file the exporter will write the resulting products'
      .option '-q, --queryString', 'Query string to specify the sub-set of products to export. Please note that the query must be URL encoded!', 'staged=true'
      .option '-l, --language [lang]', 'Language used on export for category names', 'en'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --template <file> --out <file>'
      .action (opts) ->
        CONS.DEFAULT_LANGUAGE = opts.language

        options =
          config:
            project_key: program.projectKey
            client_id: program.clientId
            client_secret: program.clientSecret
          timeout: program.timeout
          show_progress: true
          user_agent: "#{package_json.name} - Export - #{package_json.version}"
          queryString: opts.queryString
          logConfig:
            levelStream: 'warn'
            levelFile: 'warn'
        if program.verbose
          options.logConfig = 'info'
        if program.debug
          options.logConfig = 'debug'

        exporter = new Exporter options
        handleResult = (result) ->
          if result.status
            console.log result.message
            process.exit 0
          console.error result.message
          process.exit 1

        if opts.json
          # TODO: check that output extension is `.json` ?
          exporter.exportAsJson opts.json, handleResult
        else
          fs.readFile opts.template, 'utf8', (err, content) ->
            if err
              console.error "Problems on reading template file '#{opts.template}': " + err
              process.exit 2

            exporter.export content, opts.out, handleResult

    program
      .command 'template'
      .description 'Create a template for a product type of your SPHERE.IO project.'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '-l, --languages [lang,lang]', 'List of languages to use for template', @_list, ['en']
      .option '--all', 'Generates one template for all product types - if not given you will be ask which product type to use'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --out <file>'
      .action (opts) ->
        options =
          config:
            project_key: program.projectKey
            client_id: program.clientId
            client_secret: program.clientSecret
          timeout: program.timeout
          show_progress: true
          user_agent: "#{package_json.name} - Template - #{package_json.version}"
          logConfig:
            levelStream: 'warn'
            levelFile: 'warn'
        if program.verbose
          options.logConfig = 'info'
        if program.debug
          options.logConfig = 'debug'

        exporter = new Exporter options
        exporter.createTemplate opts.languages, opts.out, opts.all, (result) ->
          if result.status
            console.log result.message
            process.exit 0
          console.error result.message
          process.exit 1

    program
      .command 'groupvariants'
      .description 'Allows you to group products with its variant in order to proceed with SPHERE.IOs CSV product format.'
      .option '--in <file>', 'Path to CSV file to analyse.'
      .option '--out <file>', 'Path to the file that will contained the product/variant relations.'
      .option '--headerIndex <number>', 'Index of column (starting at 0) header, that defines the identity of variants to one product', parseInt
      .usage '--in <file> --out <file> --headerIndex <number>'
      .action (opts) ->
        variants = new Variants()
        fs.readFile opts.in, 'utf8', (err, content) ->
          if err
            console.error "Problems on reading template file '#{opts.template}': " + err
            process.exit 2
          Csv().from.string(content).to.array (data, count) ->
            header = data[0]
            header.push ['variantId']
            csv = variants.groupVariants _.rest(data), opts.headerIndex
            exporter = new Exporter()
            exporter._saveCSV opts.out, [header].concat(csv)

    program.parse argv
    program.help() if program.args.length is 0

module.exports.run process.argv
