/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
// TODO:
// - JSDoc
// - make it util only
class CustomerGroups {
  constructor() {
    this.name2id = {};
    this.id2name = {};
  }

  getAll(client) {
    return client.customerGroups.all().fetch();
  }

  buildMaps(customerGroups) {
    return _.each(customerGroups, group => {
      const { name } = group;
      const { id } = group;
      this.name2id[name] = id;
      return this.id2name[id] = name;
    });
  }
}


module.exports = CustomerGroups;
