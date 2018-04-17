/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore')
const GLOBALS = require('../lib/globals')

// TODO:
// - JSDoc
// - make it util only
class Categories {
  constructor () {
    this.id2index = {}
    this.id2externalId = {}
    this.id2slug = {}
    this.name2id = {}
    this.externalId2id = {}
    this.fqName2id = {}
    this.id2fqName = {}
    this.duplicateNames = []
  }

  getAll (client) {
    return client.categories.all().fetch()
  }

  buildMaps (categories) {
    _.each(categories, (category, index) => {
      const name = category.name[GLOBALS.DEFAULT_LANGUAGE]
      const { id } = category
      const { externalId } = category
      this.id2index[id] = index
      this.id2slug[id] = category.slug[GLOBALS.DEFAULT_LANGUAGE]
      if (_.has(this.name2id, name))
        this.duplicateNames.push(name)

      this.name2id[name] = id
      this.id2externalId[id] = externalId
      return this.externalId2id[externalId] = id
    })

    return _.each(categories, (category, index) => {
      let fqName = ''
      if (category.ancestors)
        _.each(category.ancestors, (anchestor) => {
          const cat = categories[this.id2index[anchestor.id]]
          const name = cat.name[GLOBALS.DEFAULT_LANGUAGE]
          return fqName = `${fqName}${name}${GLOBALS.DELIM_CATEGORY_CHILD}`
        })

      fqName = `${fqName}${category.name[GLOBALS.DEFAULT_LANGUAGE]}`
      this.fqName2id[fqName] = category.id
      return this.id2fqName[category.id] = fqName
    })
  }
}

module.exports = Categories
