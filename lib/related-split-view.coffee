{CompositeDisposable, Disposable} = require 'atom'
fs = require 'fs'

process.setMaxListeners(0);

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

        if (fs.existsSync(rootDir + '/App_Resources/') && fs.existsSync(rootDir + '/app.js')) || (fs.existsSync(rootDir + '/app/App_Resources/') && fs.existsSync(rootDir + '/app/app.js'))
            @projectType = 'nativescript'

        if (fs.existsSync(rootDir + '/../ionic.config.json') || fs.existsSync(rootDir + '/ionic.config.json'))
            @projectType = 'ionic'

        if (fs.existsSync(rootDir + '/.enable-rsv'))
            @projectType = 'other'

        if !@projectType
            console.error 'Not in a valid project'
            return

        console.log @projectType

        @workspace = atom.workspace

        @panes = atom.workspace.getCenter().getPanes()

        atom.config.set('core.destroyEmptyPanes', false)
        atom.config.set('core.allowPendingPaneItems', false)

        if @panes.length == 0
            @workspace.open()

        if @panes.length == 1
            @panes[0].splitRight()
            @panes = atom.workspace.getCenter().getPanes()

        if @panes.length == 2
            @panes[1].splitDown()
            @panes = atom.workspace.getCenter().getPanes()

        @paneLeft = @panes[0]
        @paneRightTop = @panes[1]
        @paneRightBottom = @panes[2]

        @paneLeft.destroy = () =>
            return

        @paneRightTop.destroy = () =>
            return

        @paneRightBottom.destroy = () =>
            return

        atom.workspace.addOpener(@opener)
 
        @observeOnDidOpen =  atom.workspace.onDidOpen(@onDidOpen);

        @observeActiveLeftPaneItemEvent = @paneLeft.onDidChangeActiveItem (items) => @onActivateLeftPane(items)
        @observerOnDidMoveLeftPaneItemEvent = @paneLeft.onDidMoveItem (e) => @onDidMoveLeftPaneItem(e)
        @observerOnWillRemoveItemLeftPaneItemEvent = @paneLeft.onWillRemoveItem (e) => @onWillRemoveItemLeftPaneItem(e)

    onDidOpen: (event) -> 
        suffix = event?.uri?.match(/(\w*)$/)[1]

        if suffix in ['js', 'ts']
            if event?.pane != MvcSplit.paneLeft
                MvcSplit.swapEditor(event?.pane, MvcSplit.paneLeft, event?.item)

            MvcSplit.openRelated(event?.uri)

        atom.views.getView(event.item).focus();
                
    swapEditor: (source, target, item) ->
        source.removeItem item
        target.addItem item
        target.activateItem item
 
    deactivate: ->
        console.log '::Destroy::'

        atom.config.set('core.destroyEmptyPanes', true)

    onWillRemoveItemLeftPaneItem: (e) ->
        uris = @getURIs(e.item.getURI(), @projectType);

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
        uris = @getURIs(e.item.getURI(), @projectType);

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
            index = @paneLeft.getActiveItemIndex()

            @paneRightTop.activateItemAtIndex(index)
            @paneRightBottom.activateItemAtIndex(index)                            

    openRelated: (uri, options={}, addEventListener=false) ->
        uris = @getURIs(uri, @projectType);
        
        if fs.existsSync(uris.styleUri) && !atom.workspace.paneForURI(uris.styleUri)
            atom.workspace.openURIInPane(uris.styleUri, @paneRightTop, {activatePane: false}).then((item) -> 
                MvcSplit.paneLeft.activateItem(MvcSplit.paneLeft.itemForURI(uri))
                index = MvcSplit.paneLeft.getActiveItemIndex()

                styleItem = MvcSplit.paneRightTop.itemForURI(uris.styleUri)
                MvcSplit.paneRightTop.moveItem(styleItem, index)
            )

        if fs.existsSync(uris.viewUri) && !atom.workspace.paneForURI(uris.viewUri)
            atom.workspace.openURIInPane(uris.viewUri, @paneRightBottom, {activatePane: false}).then((item) -> 
                MvcSplit.paneLeft.activateItem(MvcSplit.paneLeft.itemForURI(uri))
                index = MvcSplit.paneLeft.getActiveItemIndex()

                viewItem = MvcSplit.paneRightBottom.itemForURI(uris.viewUri)
                MvcSplit.paneRightBottom.moveItem(viewItem, index)
            )

    getURIs: (uri, projectType) ->
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
                uris.styleUri = uri.replace('.xml', '.css')
                uris.viewUri = uri

        if projectType == 'other' || projectType == 'ionic'
            if uri.indexOf('.js') != -1
                uris.jsUri = uri
                uris.styleUri = uri.replace('.js', '.css')
                uris.viewUri = uri.replace('.js', '.html')

            if uri.indexOf('.css') != -1 || uri.indexOf('.scss') != -1
                if uri.indexOf('.css') != -1
                    uris.jsUri = uri.replace('.css', '.js')
                    uris.styleUri = uri
                    uris.viewUri = uri.replace('.css', '.html')

                if uri.indexOf('.scss') != -1
                    uris.jsUri = uri.replace('.scss', '.js')
                    uris.styleUri = uri
                    uris.viewUri = uri.replace('.scss', '.html')

            if uri.indexOf('.html') != -1
                uris.jsUri = uri.replace('.html', '.js')
                uris.styleUri = uri.replace('.html', '.css')
                uris.viewUri = uri

        if !uris.jsUri && !uris.styleUri && !uris.viewUri
            uris = false

        return uris

    opener: (uri, options) ->
        if uri && uri.indexOf && uri.indexOf('js') != -1
            MvcSplit.paneLeft.activate()