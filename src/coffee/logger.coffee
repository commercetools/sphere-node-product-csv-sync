{Logger} = require 'sphere-node-utils'

class MyCustomLogger extends Logger
  @appName: require('../package.json').name

module.exports = (scope, logLevel = 'info') ->
  new MyCustomLogger
    name: scope
    levelStream: logLevel
