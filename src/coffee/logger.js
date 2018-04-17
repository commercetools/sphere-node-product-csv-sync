/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const {Logger} = require('sphere-node-utils');

class MyCustomLogger extends Logger {
  static initClass() {
    this.appName = require('../package.json').name;
  }
}
MyCustomLogger.initClass();

module.exports = function(scope, logLevel) {
  if (logLevel == null) { logLevel = 'info'; }
  return new MyCustomLogger({
    name: scope,
    levelStream: logLevel
  });
};
