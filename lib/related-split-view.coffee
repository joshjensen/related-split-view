{CompositeDisposable, Disposable} = require 'atom'
fs = require 'fs'

getURIs = (uri, projectType) ->
    uris = {}

    if !uri || uri == ''
        return uris

    if projectType == 'alloy'
        if uri.indexOf('.js') != -1 && uri.indexOf('controllers') != -1
            uris.jsUri = uri
            uris.styleUri = uri.replace('/controllers/', '/styles/').replace('.js', '.tss')
            uris.viewUri = uri.replace('/controllers/', '/views/').replace('.js', '.xml')

        if uri.indexOf('.tss') != -1 && uri.indexOf('styles') != -1
            uris.jsUri = uri.replace('/styles/', '/controllers/').replace('.tss', '.js')
            uris.styleUri = uri
            uris.viewUri = uri.replace('/styles/', '/views/').replace('.tss', '.xml')

        if uri.indexOf('.xml') != -1 && uri.indexOf('views') != -1
            uris.jsUri = uri.replace('/views/', '/controllers/').replace('.xml', '.js')
            uris.styleUri = uri.replace('/views/', '/styles/').replace('.xml', '.tss')
            uris.viewUri = uri

    if projectType == 'nativescript'
        if uri.indexOf('.js') != -1
            uris.jsUri = uri
            uris.styleUri = uri.replace('.js', '.css')
            uris.viewUri = uri.replace('.js', '.xml')

        if uri.indexOf('.ts') != -1
            uris.jsUri = uri
            uris.styleUri = uri.replace('.ts', '.css')
            uris.viewUri = uri.replace('.ts', '.xml')            

        if uri.indexOf('.css') != -1
            uris.jsUri = uri.replace('.css', '.js')
            uris.styleUri = uri
            uris.viewUri = uri.replace('.css', '.xml')

        if uri.indexOf('.xml') != -1
            uris.jsUri = uri.replace('.xml', '.js')
            uris.styleUri = uri.replace('.xml', '.tss')
            uris.viewUri = uri

    if !uris.jsUri && !uris.styleUri && !uris.viewUri
        uris = false

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
        rootDir = null
        if atom.project.rootDirectories[0] && atom.project.rootDirectories[0].path
            rootDir = atom.project.rootDirectories[0].path

        if fs.existsSync(rootDir + '/alloy.js') || fs.existsSync(rootDir + '/app/alloy.js')
            @projectType = 'alloy'

        if fs.existsSync(rootDir + '/App_Resources/') || fs.existsSync(rootDir + '/app.js')
            @projectType = 'nativescript'

        if !@projectType
            console.error 'Not in an Alloy or NativeScript project'
            return

        atom.config.set('core.destroyEmptyPanes', false)

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

        atom.workspace.open = (uri, options={}) =>
            uri = uri || ''

            if uri.indexOf('atom:') != -1 || uri == ''
                return atom.workspace.openURIInPane(uri, @paneLeft, options)
            else
                return this.openRelated(uri, options={})

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

        if !uris
            return atom.workspace.openURIInPane(uri, @paneLeft, options)

        returnFunction = null;

        if fs.existsSync(uris.styleUri)
            returnFunction = atom.workspace.openURIInPane(uris.styleUri, @paneRightTop)

        if fs.existsSync(uris.viewUri)
            returnFunction = atom.workspace.openURIInPane(uris.viewUri, @paneRightBottom)

        if fs.existsSync(uris.jsUri)
            returnFunction = atom.workspace.openURIInPane(uris.jsUri, @paneLeft)

        returnFunction
