Importer = require '../lib/import'
Exporter = require '../lib/export'
package_json = require '../package.json'
CONS = require '../lib/constants'
fs = require 'fs'
program = require 'commander'

program
  .version package_json.version
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
  .usage 'run import --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --csv <file>'
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
  .usage 'run state --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --changeTo (un)publish', 'will unpublish your published products'
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
  .option '-q, --queryString', 'Query string to specify the subset of products to export. Please note that the query must be URL encoded!', 'staged=true&limit=0'
  .usage 'run export --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --template <file> --out <file>'
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
  .option '-l, --languages', 'List of language to use for template', ['en']
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

    console.log "O", opts
    exporter = new Exporter options
    exporter.createTemplate program, program.languages, opts.out, (result) ->
      if result.status
        console.log result.message
        process.exit 0
      console.error result.message
      process.exit 1

program.parse process.argv
program.help() if program.args.length is 0