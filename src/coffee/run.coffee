Importer = require '../lib/import'
Exporter = require '../lib/export'
Variants = require '../lib/variants'
package_json = require '../package.json'
CONS = require '../lib/constants'
fs = require 'fs'
Q = require 'q'
program = require 'commander'
prompt = require 'prompt'
{ProjectCredentialsConfig} = require 'sphere-node-utils'
Csv = require 'csv'
_ = require('underscore')._

module.exports = class

  @_list: (val) -> _.map val.split(','), (v) -> v.trim()

  @_getFilterFunction: (opts) ->
    deferred = Q.defer()
    if opts.csv
      fs.readFile opts.csv, 'utf8', (err, content) ->
        if err
          console.error "Problems on reading identity file '#{opts.csv}': #{err}"
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
      .option '--timeout [millis]', 'Set timeout for requests (default is 300000)', parseInt, 300000
      .option '--verbose', 'give more feedback during action'
      .option '--debug', 'give as many feedback as possible'


    program
      .command 'import'
      .description 'Import your products from CSV into your SPHERE.IO project.'
      .option '-c, --csv <file>', 'CSV file containing products to import'
      .option '-l, --language [lang]', 'Default language to using during import (for slug generation, category linking etc. - default is en)', 'en'
      .option '--customAttributesForCreationOnly <items>', 'List of comma-separated attributes to use when creating products (ignore when updating)', @_list
      .option '--continueOnProblems', 'When a product does not validate on the server side (400er response), ignore it and continue with the next products'
      .option '--suppressMissingHeaderWarning', 'Do not show which headers are missing per produt type.'
      .option '--allowRemovalOfVariants', 'If given variants will be removed if there is no corresponding row in the CSV. Otherwise they are not touched.'
      .option '--ignoreSeoAttributes', 'If true all meta* attrbutes are kept untouched.'
      .option '--publish', 'When given, all changes will be published immediately'
      .option '--dryRun', 'Will list all action that would be triggered, but will not POST them to SPHERE.IO'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --csv <file>'
      .action (opts) ->
        CONS.DEFAULT_LANGUAGE = opts.language

        credentialsConfig = ProjectCredentialsConfig.create()
        .fail (err) ->
          console.error "Problems on getting client credentials from config files: #{err}"
          process.exit 2
        .then (credentials) ->
          options =
            config: credentials.enrichCredentials
              project_key: program.projectKey
              client_id: program.clientId
              client_secret: program.clientSecret
            timeout: program.timeout
            show_progress: true
            user_agent: "#{package_json.name} - Import - #{package_json.version}"
            logConfig:
              streams: [
                {level: 'warn', stream: process.stdout}
              ]
          if program.verbose
            options.logConfig.streams = [
              {level: 'info', stream: process.stdout}
            ]
          if program.debug
            options.logConfig.streams = [
              {level: 'debug', stream: process.stdout}
            ]

          importer = new Importer options
          importer.blackListedCustomAttributesForUpdate = opts.customAttributesForCreationOnly or []
          importer.continueOnProblems = opts.continueOnProblems
          importer.validator.suppressMissingHeaderWarning = opts.suppressMissingHeaderWarning
          importer.allowRemovalOfVariants = opts.allowRemovalOfVariants
          importer.syncSeoAttributes = false if opts.ignoreSeoAttributes
          importer.publishProducts = opts.publish
          importer.dryRun = true if opts.dryRun

          fs.readFile opts.csv, 'utf8', (err, content) ->
            if err
              console.error "Problems on reading file '#{opts.csv}': #{err}"
              process.exit 2
            else
              importer.import(content)
              .then (result) ->
                console.log result
                process.exit 0
              .fail (err) ->
                console.error err
                process.exit 1
              .done()
        .done()


    program
      .command 'state'
      .description 'Allows to publish, unpublish or delete (all) products of your SPHERE.IO project.'
      .option '--changeTo <publish,unpublish,delete>', 'publish unpublished products / unpublish published products / delete unpublished products'
      .option '--csv <file>', 'processes products defined in a CSV file by either "sku" or "id". Otherwise all products are processed.'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --changeTo <state>'
      .option '--continueOnProblems', "When a there is a problem on changing a product's state (400er response), ignore it and continue with the next products"
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
            streams: [
              {level: 'warn', stream: process.stdout}
            ]

          if program.verbose
            options.logConfig.streams = [
              {level: 'info', stream: process.stdout}
            ]
          if program.debug
            options.logConfig.streams = [
              {level: 'debug', stream: process.stdout}
            ]

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
              console.log result
              process.exit 0
            .fail (err) ->
              console.error err
              process.exit 1
            .done()

          if remove
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
                console.log 'Cancelled.'
                process.exit 9
          else
            run options
        .done()


    program
      .command 'export'
      .description 'Export your products from your SPHERE.IO project to CSV using.'
      .option '-t, --template <file>', 'CSV file containing your header that defines what you want to export'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '-j, --json <file>', 'Path to the JSON file the exporter will write the resulting products'
      .option '-q, --queryString', 'Query string to specify the sub-set of products to export. Please note that the query must be URL encoded!', 'staged=true'
      .option '-l, --language [lang]', 'Language used on export for category names (default is en)', 'en'
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
            streams: [
              {level: 'warn', stream: process.stdout}
            ]
        if program.verbose
          options.logConfig.streams = [
            {level: 'info', stream: process.stdout}
          ]
        if program.debug
          options.logConfig.streams = [
            {level: 'debug', stream: process.stdout}
          ]

        exporter = new Exporter options
        if opts.json
          exporter.exportAsJson(opts.json)
          .then (result) ->
            console.log result
            process.exit 0
          .fail (err) ->
            console.error err
            process.exit 1
          .done()
        else
          fs.readFile opts.template, 'utf8', (err, content) ->
            if err
              console.error "Problems on reading template file '#{opts.template}': #{err}"
              process.exit 2
            else
            exporter.export(content, opts.out)
            .then (result) ->
              console.log result
              process.exit 0
            .fail (err) ->
              console.error err
              process.exit 1
            .done()


    program
      .command 'template'
      .description 'Create a template for a product type of your SPHERE.IO project.'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '-l, --languages [lang,lang]', 'List of languages to use for template (default is [en])', @_list, ['en']
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
            streams: [
              {level: 'warn', stream: process.stdout}
            ]
        if program.verbose
          options.logConfig.streams = [
            {level: 'info', stream: process.stdout}
          ]
        if program.debug
          options.logConfig.streams = [
            {level: 'debug', stream: process.stdout}
          ]

        exporter = new Exporter options
        exporter.createTemplate(opts.languages, opts.out, opts.all)
        .then (result) ->
          console.log result
          process.exit 0
        .fail (err) ->
          console.error err
          process.exit 1
        .done()


    # TODO: remove
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
            console.error "Problems on reading template file '#{opts.template}': #{err}"
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
