Import = require '../lib/import'
CONS = require '../lib/constants'
fs = require 'fs'
argv = require('optimist')
  .usage('Usage: $0 --projectKey key --clientId id --clientSecret secret --csv file --language lang --staging')
  .default('lang', 'en')
  .describe('projectKey', 'your SPHERE.IO project-key')
  .describe('clientId', 'your OAuth client id for the SPHERE.IO API')
  .describe('clientSecret', 'your OAuth client secret for the SPHERE.IO API')
  .describe('csv', 'CSV file containing products to validate or import')
  .demand(['projectKey', 'clientId', 'clientSecret', 'csv'])
  .argv

timeout = argv.timeout
timeout or= 60000

CONS.DEFAULT_LANGUAGE = argv.language

options =
  config:
    project_key: argv.projectKey
    client_id: argv.clientId
    client_secret: argv.clientSecret
  timeout: timeout
  show_progress: true

if argv.staging
  options.oauth_host = 'auth_sphere_cloud.commercetools.de'
  options.host = 'api_sphere_cloud.commercetools.de'
  options.rejectUnauthorized = false

importer = new Import options

fs.readFile argv.csv, 'utf8', (err, content) ->
  if err
    console.error "Problems on reading file '#{argv.csv}': " + err
    process.exit 2

  importer.import content, (result) ->
    console.log result.message
    process.exit 0 if result.status is true
    process.exit 1