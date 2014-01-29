Import = require '../lib/import'
fs = require 'fs'
argv = require('optimist')
  .usage('Usage: $0 --projectKey key --clientId id --clientSecret secret --csv file')
  .describe('projectKey', 'your SPHERE.IO project-key')
  .describe('clientId', 'your OAuth client id for the SPHERE.IO API')
  .describe('clientSecret', 'your OAuth client secret for the SPHERE.IO API')
  .describe('csv', 'CSV file containing products to validate or import')
  .demand(['projectKey', 'clientId', 'clientSecret', 'csv'])
  .argv

timeout = argv.timeout
timeout or= 60000

options =
  config:
    project_key: argv.projectKey
    client_id: argv.clientId
    client_secret: argv.clientSecret
  timeout: timeout
  oauth_host: 'auth.escemo.com'
  host: 'api.escemo.com'
  rejectUnauthorized: false

importer = new Import options

fs.readFile argv.csv, 'utf8', (err, content) ->
  if err
    console.error "Problems on reading file '#{argv.csv}': " + err
    process.exit 2

  importer.import content, (result) ->
    console.log result.message
    process.exit 0 if result.status is true
    process.exit 1