Importer = require '../lib/import'
Exporter = require '../lib/export'
Variants = require '../lib/variants'
package_json = require '../package.json'
CONS = require '../lib/constants'
fs = require 'fs'
program = require 'commander'

Csv = require 'csv'
_ = require('underscore')._

module.exports = class

  @_list: (val) -> val.split ','

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
      .option '-l, --language [lang]', 'Default language to using during import', 'en'
      .option 'publish', 'When given, all changes will be published immediately'
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
        if program.verbose
          options.logConfig = 'info'
        if program.debug
          options.logConfig = 'debug'

        importer = new Importer options
        importer.publishProducts = opts.publish

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
      .description 'Allows to publish or unpublish all products of your project.'
      .option '--changeTo <publish,unpublish>', 'publish all unpublish products/unpublish all published products'
      .usage '--projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --changeTo (un)publish', 'will unpublish your published products'
      .action (opts) ->

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
        if program.verbose
          options.logConfig = 'info'
        if program.debug
          options.logConfig = 'debug'

        publish = switch opts.changeTo
          when 'publish' then true
          when 'unpublish' then false
          else
            console.error "Unknown argument '#{opts.changeTo}' for option changeTo!"
            process.exit 2

        importer = new Import options
        importer.publishOnly publish, (result) ->
          if result.status
            console.log result.message
            process.exit 0
          console.error result.message
          process.exit 1

    program
      .command 'export'
      .description 'Export your products from your SPHERE.IO project to CSV using.'
      .option '-t, --template <file>', 'CSV file containing your header that defines what you want to export'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '-q, --queryString', 'Query string to specify the sub-set of products to export. Please note that the query must be URL encoded!', 'staged=true&limit=0'
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
        if program.verbose
          options.logConfig = 'info'
        if program.debug
          options.logConfig = 'debug'

        exporter = new Exporter options

        fs.readFile opts.template, 'utf8', (err, content) ->
          if err
            console.error "Problems on reading template file '#{opts.template}': " + err
            process.exit 2

          exporter.export content, opts.out, (result) ->
            if result.status
              console.log result.message
              process.exit 0
            console.error result.message
            process.exit 1

    program
      .command 'template'
      .description 'Create a template based on a product type of your SPHERE.IO project.'
      .option '-o, --out <file>', 'Path to the file the exporter will write the resulting CSV in'
      .option '-l, --languages [lang,lang]', 'List of language to use for template', @_list, ['en']
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
        if program.verbose
          options.logConfig = 'info'
        if program.debug
          options.logConfig = 'debug'

        exporter = new Exporter options
        exporter.createTemplate program, opts.languages, opts.out, (result) ->
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