# TODO:
# - JSDoc
# - make it util only
class CustomerGroups
  constructor: ->
    @name2id = {}
    @id2name = {}

  getAll: (client) ->
    client.customerGroups.all().fetch()

  buildMaps: (customerGroups) ->
    for group in customerGroups
      name = group.name
      id = group.id
      @name2id[name] = id
      @id2name[id] = name


module.exports = CustomerGroups
