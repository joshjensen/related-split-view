{CompositeDisposable, Disposable} = require 'atom'
fs = require 'fs'

getURIs = (uri, projectType) ->
  uris = {}

  if !uri || uri == ''
    return uris

  if projectType == 'alloy'
    if uri.indexOf('.js') != -1
      uris.jsUri = uri
      uris.styleUri = uri.replace('/controllers/', '/styles/').replace('.js', '.tss')
      uris.viewUri = uri.replace('/controllers/', '/views/').replace('.js', '.xml')

    if uri.indexOf('.tss') != -1
      uris.jsUri = uri.replace('/styles/', '/controllers/').replace('.tss', '.js')
      uris.styleUri = uri
      uris.viewUri = uri.replace('/styles/', '/views/').replace('.tss', '.xml')

    if uri.indexOf('.xml') != -1
      uris.jsUri = uri
      uris.styleUri = uri.replace('/controllers/', '/styles/').replace('.js', '.tss')
      uris.viewUri = uri.replace('/controllers/', '/views/').replace('.js', '.xml')

  return uris

module.exports = MvcSplit =
  projectType: null
  paneLeft: null
  paneRightTop: null
  paneRightBottom: null
  panes: null
  editor: null
  observeActiveLeftPaneItemEvent: null
  observerOnDidMoveLeftPaneItemEvent: null
  observerOnDidDestroyLeftPaneItemEvent: null

  activate: ->
    atom.config.set('core.destroyEmptyPanes', false)
    rootDir = null
    if atom.project.rootDirectories[0] && atom.project.rootDirectories[0].path
      rootDir = atom.project.rootDirectories[0].path
      if fs.existsSync(rootDir + '/alloy.js') || fs.existsSync(rootDir + '/app/alloy.js')
        @projectType = 'alloy'

    if !@projectType
      console.error 'Not in an Alloy or NativeScript project'
      return

    @workspace = atom.workspace

    @panes = @workspace.getPanes()

    if @panes.length == 0
      @workspace.open()

    if @panes.length == 1
      @panes[0].splitRight()
      @panes = @workspace.getPanes()

    if @panes.length == 2
      @panes[1].splitDown()
      @panes = @workspace.getPanes()

    @paneLeft = @panes[0]
    @paneRightTop = @panes[1]
    @paneRightBottom = @panes[2]
    console.log atom.workspace

    atom.workspace.open = (uri, options={}) =>
      uri = uri || ''
      if uri.indexOf 'atom:' != -1 || uri == ''
        atom.workspace.openURIInPane(uri, @paneLeft, options)
      else
        this.openRelated(uri, options={})

    @observeActiveLeftPaneItemEvent = @paneLeft.onDidChangeActiveItem (items) => @onActivateLeftPane(items)
    @observerOnDidMoveLeftPaneItemEvent = @paneLeft.onDidMoveItem (e) => @onDidMoveLeftPaneItem(e)
    @observerOnWillRemoveItemLeftPaneItemEvent = @paneLeft.onWillRemoveItem (e) => @onWillRemoveItemLeftPaneItem(e)

  deactivate: ->
    atom.config.set('core.destroyEmptyPanes', true)
    @observeActiveLeftPaneItemEvent.dispose()
    @observeActiveRightTopPaneItemEvent.dispose()
    @observerOnWillRemoveItemLeftPaneItemEvent.dispose()

    atom.workspace.open = (uri, options={}) ->
      searchAllPanes = options.searchAllPanes
      split = options.split
      uri = atom.project.resolvePath(uri)

      pane = atom.workspace.paneContainer.paneForURI(uri) if searchAllPanes
      pane ?= switch split
        when 'left'
          atom.workspace.getActivePane().findLeftmostSibling()
        when 'right'
          atom.workspace.getActivePane().findOrCreateRightmostSibling()
        else
          atom.workspace.getActivePane()

      atom.workspace.openURIInPane(uri, pane, options)

  onWillRemoveItemLeftPaneItem: (e) ->
    uris = getURIs(e.item.getURI(), @projectType);

    if uris.styleUri
      styleItem = @paneRightTop.itemForURI(uris.styleUri)
      if styleItem
          @paneRightTop.destroyItem(styleItem)

    if uris.viewUri
      viewItem = @paneRightBottom.itemForURI(uris.viewUri)
      if viewItem
          @paneRightBottom.destroyItem(viewItem)

  onDidMoveLeftPaneItem: (e) ->
    newIndex = e.newIndex
    uris = getURIs(e.item.getURI(), @projectType);

    if uris.styleUri
      styleItem = @paneRightTop.itemForURI(uris.styleUri)
      if styleItem
          @paneRightTop.moveItem(styleItem, newIndex)

    if uris.viewUri
      viewItem = @paneRightBottom.itemForURI(uris.viewUri)
      if viewItem
          @paneRightBottom.moveItem(viewItem ,newIndex)

  onActivateLeftPane: (item) ->
    if item && @observeActiveLeftPaneItemEvent
      @openRelated(item.getURI(), {})

  openRelated: (uri, options={}, addEventListener=false) ->
    uris = getURIs(uri, @projectType);
    if fs.existsSync(uris.styleUri)
      @workspace.openURIInPane(uris.styleUri, @paneRightTop)

    if fs.existsSync(uris.viewUri)
      @workspace.openURIInPane(uris.viewUri, @paneRightBottom)

    if fs.existsSync(uris.jsUri)
      @workspace.openURIInPane(uris.jsUri, @paneLeft)
