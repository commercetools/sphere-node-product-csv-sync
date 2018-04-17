/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');

// TODO:
// - JSDoc
// - make it util only
class Taxes {
  constructor() {
    this.name2id = {};
    this.id2name = {};
    this.duplicateNames = [];
  }

  getAll(client) {
    return client.taxCategories.all().fetch();
  }

  buildMaps(taxCategories) {
    return _.each(taxCategories, taxCat => {
      const { name } = taxCat;
      const { id } = taxCat;

      this.id2name[id] = name;

      if (_.has(this.name2id, name)) {
        this.duplicateNames.push(name);
      }
      return this.name2id[name] = id;
    });
  }
}


module.exports = Taxes;
