/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
class Helpers {
  static initMap (key, value) {
    const map = {}
    map[key] = value
    return map
  }
}

module.exports = Helpers
