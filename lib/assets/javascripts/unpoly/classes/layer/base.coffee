#= require ../record
#= require ../config

e = up.element
u = up.util

class up.Layer extends up.Record

  keys: ->
    [
      'stack',
      'history',
      'mode',
      'context',
    ]

  defaults: ->
    context: {}

  constructor: (options = {}) ->
    super(options)

    unless @mode
      throw "missing { mode } option"

    # If an ancestor layer was opened with the wish to not affect history,
    # this child layer should not affect it either.
    if parent = @parent
      @history &&= parent.history

  isCurrent: ->
    @stack.current == this

  isLeaf: ->
    @stack.isLeaf(this)

  isRoot: ->
    @stack.isRoot(this)

  isOverlay: ->
    @stack.isOverlay(this)

  isOpen: ->
    @stack.isOpen(this)

  defaultTargets: ->
    up.layer.defaultTargets(@mode)

  sync: ->
    # no-op so users can blindly sync without knowing the current mode

  # no-op so users can blindly accept even though they might be on the root layer
  accept: u.asyncNoop

  # no-op so users can blindly dismiss even though they might be on the root layer
  dismiss: u.asyncNoop

  peel: (options) ->
    @stack.peel(this, options)

  evalOption: (option) ->
    u.evalOption(option, this)

  allElements: (selector) ->
    throw up.error.notImplemented()

  firstElement: (selector) ->
    @allElements(selector)[0]

  @getter 'parent', ->
    @stack.parentOf(this)

  contains: (element) =>
    throw up.error.notImplemented()

  on: (args...) ->
    return @buildEventListenerGroup(args).bind()

  off: (args...) ->
    return @buildEventListenerGroup(args).unbind()

  buildEventListenerGroup: (args) ->
    return up.EventListenerGroup.fromBindArgs(args,
      guard: @containsEventTarget,
      elements: [@element]
    )

  containsEventTarget: (event) =>
    @contains(event.target)

  buildEventEmitter: (args) ->
    return up.EventEmitter.fromEmitArgs(args, element: @element)

  emit: (args...) ->
    return @buildEventEmitter(args).emit()

  whenEmitted: (args...) ->
    return @buildEventEmitter(args).whenEmitted()

  isOpen: ->
    @stack.isOpen(this)

  saveHistory: ->
    return unless @history

    @savedTitle = document.title
    @savedLocation = up.history.location

  restoreHistory: ->
    if @savedLocation
      up.history.push(@savedLocation)
      @savedLocation = null

    if @savedTitle
      document.title = @savedTitle
      @savedTitle = null

  asCurrent: (fn) ->
    @stack.asCurrent(this, fn)

  updateHistory: (options) ->
    # When the layer is opened, the { history } option defines whether the
    # layer enables handling of location and title in general.
    # When updating history, accept { history: false } as a shortcut to
    # neither change { title } nor { location }.
    return if options.history == false

    if title = options.title
      @title = title

    if location = options.location
      @location = location

  @accessor 'title',
    get: ->
      if @hasLiveHistory()
        # Allow Unpoly-unaware code to set the document title directly.
        # This will implicitely change the current layer's title.
        document.title
      else
        @savedTitle

    set: (title) ->
      @savedTitle = title

      if @hasLiveHistory()
        document.title = title

  @accessor 'location',
    get: ->
      if @hasLiveHistory()
        # Allow Unpoly-unaware code to use the pushState API directly.
        # This will implicitely change the current layer's location.
        up.browser.location
      else
        @savedLocation

    set: (location) ->
      @savedLocation = location

      if @hasLiveHistory()
        up.history.push(location)
      else
        # up.feedback won't receive an up:history:push event
        up.feedback.updateLayer(this)

  hasLiveHistory: ->
    @history && @isLeaf()

  toString: ->
    "#{@mode} layer"
