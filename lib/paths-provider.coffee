{Range}  = require('atom')
fuzzaldrin = require('fuzzaldrin')
path = require('path')
fs = require('fs')

module.exports =
class PathsProvider
  id: 'autocomplete-paths-pathsprovider'
  selector: '*'
  # wordRegex: /(?:[a-zA-Z]:)?.*(?:\/|\\\\?).*/g
  wordRegex: /(?:<%=\s?path\s?%>)?(?:[a-zA-Z]:)?[a-zA-Z0-9./\\_-]*(?:\/|\\\\?)[a-zA-Z0-9./\\_-]*/g
  cache: []

  requestHandler: (options = {}) =>
    return [] unless options.editor? and options.buffer? and options.cursor?
    editorPath = options.editor?.getPath()
    return [] unless editorPath?.length
    # basePath は現在のドキュメントのフォルダのパス
    basePath = path.dirname(editorPath)
    return [] unless basePath?

    # prefixは補完に引き渡される文字列
    prefix = @prefixForCursor(options.editor, options.buffer, options.cursor, options.position)
    return [] unless prefix.length

    suggestions = @findSuggestionsForPrefix(options.editor, options.cursor, basePath, prefix)
    return [] unless suggestions.length
    return suggestions

  prefixForCursor: (editor, buffer, cursor, position) =>
    return '' unless buffer? and cursor?
    start = @getBeginningOfCurrentWordBufferPosition(editor, position, {wordRegex: @wordRegex})
    end = cursor.getBufferPosition()
    return '' unless start? and end?
    buffer.getTextInRange(new Range(start, end))

  getBeginningOfCurrentWordBufferPosition: (editor, position, options = {}) ->
    return unless position?
    allowPrevious = options.allowPrevious ? true
    currentBufferPosition = position
    scanRange = [[currentBufferPosition.row, 0], currentBufferPosition]
    beginningOfWordPosition = null
    editor.backwardsScanInBufferRange (options.wordRegex), scanRange, ({range, stop}) ->
      if range.end.isGreaterThanOrEqual(currentBufferPosition) or allowPrevious
        beginningOfWordPosition = range.start
      if not beginningOfWordPosition?.isEqual(currentBufferPosition)
        stop()

    if beginningOfWordPosition?
      beginningOfWordPosition
    else if allowPrevious
      [currentBufferPosition.row, 0]
    else
      currentBufferPosition

  findSuggestionsForPrefix: (editor, cursor, basePath, prefix) ->
    return [] unless basePath?

    projectPath = atom.project.getPaths()[0]
    rootPath = ''
    try
      rootPath = fs.readFileSync projectPath + '/.rootpath', 'utf8'
      rootPath = projectPath + '/' + rootPath.replace(/[\n\r].*/, '').trim()
    rootRegexp = new RegExp '^' + rootPath
    # 指定したルートフォルダがある場合で"/"から始まる場合
    if rootPath && basePath.match(rootRegexp) && prefix.match(/^\//)
      prefix = prefix.replace(/^\//, '')
      basePath = rootPath
    # 指定したルートフォルダがある場合で"<%= path %>"から始まる場合
    if rootPath && basePath.match(rootRegexp) && prefix.match(/<%=\s?path\s?%>/)
      prefix = prefix.replace(/.*<%=\s?path\s?%>/, '')
      basePath = rootPath
    prefixPath = path.resolve(basePath, prefix)
    # プロジェクト設定でスコープの指定があった場合
    fileExtensionsExclude = atom.config.get('autocomplete-paths-alt.fileExtensionsExclude')
    scopeDecriptor = cursor.getScopeDescriptor()
    scopeFlag = false
    # プロジェクト設定で設定されたスコープの場合は拡張子をつけない
    for key, source of fileExtensionsExclude
      if scopeDecriptor.scopes.indexOf(source) >= 0
        scopeFlag = true
        break


    if prefix.match(/[/\\]$/)
      directory = prefixPath
      prefix = ''
    else
      if basePath is prefixPath
        directory = prefixPath
      else
        directory = path.dirname(prefixPath)
      prefix = path.basename(prefix)

    # Is this actually a directory?
    try
      stat = fs.statSync(directory)
      return [] unless stat.isDirectory()
    catch e
      return []

    # Get files
    try
      files = fs.readdirSync(directory)
    catch e
      return []
    results = fuzzaldrin.filter(files, prefix)

    suggestions = for result in results
      resultPath = path.resolve(directory, result)

      # Check for type
      try
        stat = fs.statSync(resultPath)
      catch e
        continue
      if stat.isDirectory()
        label = 'Dir'
      else if stat.isFile()
        label = 'File'
        if scopeFlag
          result = result.replace(/\..+$/, '')
      else
        continue

      suggestion =
        word: result
        prefix: prefix
        label: label
        data:
          body: result
      if suggestion.label isnt 'File'
        suggestion.onDidConfirm = ->
          atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:activate')

      suggestion
    return suggestions

  dispose: =>
    @editor = null
    @basePath = null
