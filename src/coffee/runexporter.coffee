Exporter = require '../lib/export'
package_json = require '../package.json'
CONS = require '../lib/constants'
fs = require 'fs'

argv = require 'optimist'
  .usage 'Usage: $0 --projectKey key --clientId id --clientSecret secret --template file --out file'
  .default 'language', 'en'
  .default 'timeout', 300000
  .default 'queryString', 'staged=true&limit=0'
  .describe 'projectKey', 'your SPHERE.IO project-key'
  .describe 'clientId', 'your OAuth client id for the SPHERE.IO API'
  .describe 'clientSecret', 'your OAuth client secret for the SPHERE.IO API'
  .describe 'template', 'CSV file containing your header that defines what you want to export'
  .describe 'out', 'Path to the file the exporter will write the resulting CSV in'
  .describe 'timeout', 'Set timeout for requests'
  .describe 'language', 'Default language used during export'
  .describe 'queryString', 'Query string to specify the subset of products to export. Please note that the query must be URL encoded!'
  .demand ['projectKey', 'clientId', 'clientSecret', 'template', 'out']
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
  queryString: argv.queryString

exporter = new Exporter options
exporter.publishProducts = argv.publish

fs.readFile argv.template, 'utf8', (err, content) ->
  if err
    console.error "Problems on reading file '#{argv.template}': " + err
    process.exit 2

  exporter.export content, argv.out, (result) ->
    if result.status
      console.log result.message
      process.exit 0
    console.error result.message
    process.exit 1