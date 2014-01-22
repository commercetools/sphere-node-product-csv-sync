Validator = require('../main').Validator
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

validator = new Validator options

fs.readFile argv.csv, 'utf8', (err, content) ->
  if err
    console.error "Problems on reading file '#{argv.csv}': " + err
    process.exit 2
  validator.parse content, (data, count) ->
    errors = validator.validate data, (then) ->
      process.exit 0 if validator.errors.length is 0
      console.log validator.errors
      process.exit 1