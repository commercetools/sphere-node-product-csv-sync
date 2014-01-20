Validator = require('../main').Validator
fs = require 'fs'
argv = require('optimist')
  .usage('Usage: $0 --projectKey key --clientId id --clientSecret secret --csv file')
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

validator = new Validator()

fs.readFile argv.csv, 'utf8', (err, content) ->
  if err
    console.error "Problems on reading file '#{argv.csv}': " + err
    process.exit 2
  validator.parse content, (data, count) ->
    errors = validator.validate data
    process.exit 0 if errors.length is 0
    console.log errors
    process.exit 1