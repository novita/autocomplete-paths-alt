module.exports =
  provider: null
  ready: false

  config:
    fileExtensionsExclude:
      title: '拡張子をつけない'
      description: '拡張子をつけないスコープをコンマ区切りで指定'
      type: 'array'
      default: []
      items:
        type: 'string'
        
  activate: ->
    @ready = true

  deactivate: ->
    @provider = null

  getProvider: ->
    return @provider if @provider?
    PathsProvider = require('./paths-provider')
    @provider = new PathsProvider()
    return @provider

  provide: ->
    return {provider: @getProvider()}
