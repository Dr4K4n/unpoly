u = up.util

class up.Record

  fields: ->
    throw 'Return an array of property names'

  constructor: (options) ->
    u.assign(@, @attributes(options))

  attributes: (source = @) =>
    u.only(source, @fields()...)

  copy: (changes = {}) =>
    attributesWithChanges = u.merge(@attributes(), changes)
    new @constructor(attributesWithChanges)
