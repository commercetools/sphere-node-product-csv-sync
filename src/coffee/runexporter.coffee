Exporter = require '../lib/export'
package_json = require '../package.json'
CONS = require '../lib/constants'
fs = require 'fs'
argv = require('optimist')
  .usage('Usage: $0 --projectKey key --clientId id --clientSecret secret --template file --out file')
  .default('language', 'en')
  .default('timeout', 300000)
  .describe('projectKey', 'your SPHERE.IO project-key')
  .describe('clientId', 'your OAuth client id for the SPHERE.IO API')
  .describe('clientSecret', 'your OAuth client secret for the SPHERE.IO API')
  .describe('template', 'CSV file containing products to import')
  .describe('out', 'CSV file containing products to import')
  .describe('timeout', 'Set timeout for requests')
  .demand(['projectKey', 'clientId', 'clientSecret'])
  .argv

CONS.DEFAULT_LANGUAGE = argv.language

options =
  config:
    project_key: argv.projectKey
    client_id: argv.clientId
    client_secret: argv.clientSecret
  timeout: argv.timeout
  show_progress: true
  user_agent: "#{package_json.name} Export - #{package_json.version}"

exporter = new Exporter options
exporter.publishProducts = argv.publish

fs.readFile argv.template, 'utf8', (err, content) ->
  if err
    console.error "Problems on reading file '#{argv.template}': " + err
    process.exit 2

  exporter.export content, argv.out, (result) ->
    console.log result.message
    process.exit 0 if result.status is true
    process.exit 1