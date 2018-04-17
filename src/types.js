/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore')
const CONS = require('./constants')

// TODO:
// - JSDoc
// - make it util only
class Types {
  constructor () {
    this.id2index = {}
    this.name2id = {}
    this.duplicateNames = []
    this.id2SameForAllAttributes = {}
    this.id2nameAttributeDefMap = {}
  }

  getAll (client) {
    return client.productTypes.all().fetch()
  }

  buildMaps (productTypes) {
    return _.each(productTypes, (pt, index) => {
      const { name } = pt
      const { id } = pt

      this.id2index[id] = index
      this.id2SameForAllAttributes[id] = []
      this.id2nameAttributeDefMap[id] = {}

      if (_.has(this.name2id, name))
        this.duplicateNames.push(name)

      this.name2id[name] = id

      if (!pt.attributes) pt.attributes = []
      return _.each(pt.attributes, (attribute) => {
        if (attribute.attributeConstraint === CONS.ATTRIBUTE_CONSTRAINT_SAME_FOR_ALL) this.id2SameForAllAttributes[id].push(attribute.name)
        return this.id2nameAttributeDefMap[id][attribute.name] = attribute
      })
    })
  }
}


module.exports = Types
