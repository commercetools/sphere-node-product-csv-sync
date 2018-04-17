/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore')
// TODO:
// - JSDoc
// - make it util only
class Channels {
  constructor () {
    this.key2id = {}
    this.id2key = {}
  }

  getAll (client) {
    return client.channels.all().fetch()
  }

  buildMaps (channels) {
    return _.each(channels, (channel) => {
      const { key } = channel
      const { id } = channel

      this.key2id[key] = id
      return this.id2key[id] = key
    })
  }
}


module.exports = Channels
