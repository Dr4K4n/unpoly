###*
Modal dialogs
=============

Instead of [linking to a page fragment](/up.link), you can choose to show a fragment
in a modal dialog. The existing page will remain open in the background.

To open a modal, add an [`up-modal`](/up-modal) attribute to a link:

    <a href="/blogs" up-modal=".blog-list">Switch blog</a>

When this link is clicked, Unpoly will request the path `/blogs` and extract
an element matching the selector `.blog-list` from the response. The matching element
will then be placed in a modal dialog.


\#\#\# Closing behavior

By default the dialog automatically closes
*when a link inside a modal changes a fragment behind the modal*.
This is useful to have the dialog interact with the page that
opened it, e.g. by updating parts of a larger form.

To disable this behavior, give the opening link an [`up-sticky`](/up-modal#up-sticky) attribute:


\#\#\# Customizing the dialog design

Dialogs have a minimal default design:

- Contents are displayed in a white box with a subtle box shadow
- The box will grow to fit the dialog contents, but never grow larger than the screen
- The box is placed over a semi-transparent backdrop to dim the rest of the page
- There is a button to close the dialog in the top-right corner

The easiest way to change how the dialog looks is to override the
[default CSS styles](https://github.com/unpoly/unpoly/blob/master/lib/assets/stylesheets/up/modal.css.sass).

By default the dialog uses the following DOM structure:

    <div class="up-modal">
      <div class="up-modal-backdrop">
      <div class="up-modal-viewport">
        <div class="up-modal-dialog">
          <div class="up-modal-content">
            <!-- the matching element will be placed here -->
          </div>
          <div class="up-modal-close" up-close>X</div>
        </div>
      </div>
    </div>

You can change this structure by setting [`up.modal.config.template`](/up.modal.config#config.template) to a new template string
or function.


@class up.modal
###
up.modal = (($) ->

  u = up.util

  ###*
  Sets default options for future modals.

  @property up.modal.config
  @param {string} [config.history=true]
    Whether opening a modal will add a browser history entry.
  @param {number} [config.width]
    The width of the dialog as a CSS value like `'400px'` or `'50%'`.

    Defaults to `undefined`, meaning that the dialog will grow to fit its contents
    until it reaches `config.maxWidth`. Leaving this as `undefined` will
    also allow you to control the width using CSS on `.up-modal-dialog´.
  @param {number} [config.maxWidth]
    The width of the dialog as a CSS value like `'400px'` or `50%`.
    You can set this to `undefined` to make the dialog fit its contents.
    Be aware however, that e.g. Bootstrap stretches input elements
    to `width: 100%`, meaning the dialog will also stretch to the full
    width of the screen.
  @param {number} [config.height='auto']
    The height of the dialog in pixels.
    Defaults to `undefined`, meaning that the dialog will grow to fit its contents.
  @param {string|Function(config)} [config.template]
    A string containing the HTML structure of the modal.
    You can supply an alternative template string, but make sure that it
    defines tag with the classes `up-modal`, `up-modal-dialog` and  `up-modal-content`.

    You can also supply a function that returns a HTML string.
    The function will be called with the modal options (merged from these defaults
    and any per-open overrides) whenever a modal opens.
  @param {string} [config.closeLabel='×']
    The label of the button that closes the dialog.
  @param {boolean} [config.closable=true]
    When `true`, the modal will render a close icon and close when the user
    clicks on the backdrop or presses Escape.

    When `false`, you need to either supply an element with `[up-close]` or
    close the modal manually with `up.modal.close()`.
  @param {string} [config.openAnimation='fade-in']
    The animation used to open the viewport around the dialog.
  @param {string} [config.closeAnimation='fade-out']
    The animation used to close the viewport the dialog.
  @param {string} [config.backdropOpenAnimation='fade-in']
    The animation used to open the backdrop that dims the page below the dialog.
  @param {string} [config.backdropCloseAnimation='fade-out']
    The animation used to close the backdrop that dims the page below the dialog.
  @param {number} [config.openDuration]
    The duration of the open animation (in milliseconds).
  @param {number} [config.closeDuration]
    The duration of the close animation (in milliseconds).
  @param {string} [config.openEasing]
    The timing function controlling the acceleration of the opening animation.
  @param {string} [config.closeEasing]
    The timing function controlling the acceleration of the closing animation.
  @param {boolean} [options.sticky=false]
    If set to `true`, the modal remains
    open even it changes the page in the background.
  @param {string} [options.flavor='default']
    The default [flavor](/up.modal.flavors).
  @stable
  ###
  config = u.config
    maxWidth: null
    width: null
    height: null
    history: true
    openAnimation: 'fade-in'
    closeAnimation: 'fade-out'
    openDuration: null
    closeDuration: null
    openEasing: null
    closeEasing: null
    backdropOpenAnimation: 'fade-in'
    backdropCloseAnimation: 'fade-out'
    closeLabel: '×'
    closable: true
    sticky: false
    flavor: 'default'
    position: null
    template: (options) ->
      """
      <div class="up-modal">
        <div class="up-modal-backdrop"></div>
        <div class="up-modal-viewport">
          <div class="up-modal-dialog">
            <div class="up-modal-content"></div>
            <div class="up-modal-close" up-close>#{options.closeLabel}</div>
          </div>
        </div>
      </div>
      """

  ###*
  Define modal variants with their own default configuration, CSS or HTML template.

  \#\#\# Example

  Unpoly's [`[up-drawer]`](/up-drawer) is implemented as a modal flavor:

      up.modal.flavors.drawer = {
        openAnimation: 'move-from-right',
        closeAnimation: 'move-to-right'
      }

  Modals with that flavor will have a container with an `up-flavor` attribute:

      <div class='up-modal' up-flavor='drawer'>
        ...
      </div>

  We can target the `up-flavor` attribute to override the default dialog styles:

      .up-modal[up-flavor='drawer'] {

        .up-modal-dialog {
          margin: 0;         // Remove margin so drawer starts at the screen edge
          max-width: 350px;  // Set drawer size
        }

        .up-modal-content {
          min-height: 100vh; // Stretch background to full window height
        }
      }

  @property up.modal.flavors
  @param {Object} flavors
    An object where the keys are flavor names (e.g. `'drawer') and
    the values are the respective default configurations.
  @experimental
  ###
  flavors = u.openConfig
    default: {}

  ###*
  Returns the source URL for the fragment displayed in the current modal overlay,
  or `undefined` if no modal is currently open.

  @function up.modal.url
  @return {string}
    the source URL
  @stable
  ###

  ###*
  Returns the URL of the page behind the modal overlay.

  @function up.modal.coveredUrl
  @return {string}
  @experimental
  ###
  
  state = u.config ->
    phase: 'closed'      # can be 'opening', 'opened', 'closing' and 'closed'
    $anchor: null        # the element to which the tooltip is anchored
    $modal: null         # the modal container
    sticky: null
    closable: null
    flavor: null
    url: null
    coveredUrl: null
    coveredTitle: null
    position: null
    unshifters: []

  chain = new u.DivertibleChain()

  reset = ->
    state.$modal?.remove()
    unshiftElements()
    state.reset()
    chain.reset()
    config.reset()
    flavors.reset()

  templateHtml = ->
    template = flavorDefault('template')
    u.evalOption(template, closeLabel: flavorDefault('closeLabel'))

  discardHistory = ->
    state.coveredTitle = null
    state.coveredUrl = null

  createHiddenFrame = (target, options) ->
    $modal = $(templateHtml())
    $modal.attr('up-flavor', state.flavor)
    $modal.attr('up-position', state.position) if u.isPresent(state.position)
    $dialog = $modal.find('.up-modal-dialog')
    $dialog.css('width', options.width) if u.isPresent(options.width)
    $dialog.css('max-width', options.maxWidth) if u.isPresent(options.maxWidth)
    $dialog.css('height', options.height) if u.isPresent(options.height)
    $modal.find('.up-modal-close').remove() unless state.closable
    $content = $modal.find('.up-modal-content')
    # Create an empty element that will match the
    # selector that is being replaced.
    u.$createPlaceholder(target, $content)
    $modal.hide()
    $modal.appendTo(document.body)
    state.$modal = $modal

  unveilFrame = ->
    state.$modal.show()

  # Gives `<body>` a right padding in the width of a scrollbar.
  # Also gives elements anchored to the right side of the screen
  # an increased `right`.
  #
  # This is to prevent the body and elements from jumping when we add the
  # modal overlay, which has its own scroll bar.
  # This is screwed up, but Bootstrap does the same.
  shiftElements = ->
    if u.documentHasVerticalScrollbar()
      $body = $('body')
      scrollbarWidth = u.scrollbarWidth()
      bodyRightPadding = parseFloat($body.css('padding-right'))
      bodyRightShift = scrollbarWidth + bodyRightPadding
      unshiftBody = u.temporaryCss($body,
        'padding-right': "#{bodyRightShift}px",
        'overflow-y': 'hidden'
      )
      state.unshifters.push(unshiftBody)
      up.layout.anchoredRight().each ->
        $element = $(this)
        elementRight = parseFloat($element.css('right'))
        elementRightShift = scrollbarWidth + elementRight
        unshifter = u.temporaryCss($element, 'right': elementRightShift)
        state.unshifters.push(unshifter)


  # Reverts the effects of `shiftElements`.
  unshiftElements = ->
    unshifter() while unshifter = state.unshifters.pop()

  ###*
  Returns whether a modal is currently open.

  This also returns `true` if the modal is in an opening or closing animation.

  @function up.modal.isOpen
  @return {boolean}
  @stable
  ###
  isOpen = ->
    state.phase == 'opened' || state.phase == 'opening'

  ###*
  Opens the given link's destination in a modal overlay:

      var $link = $('...');
      up.modal.follow($link);

  Any option attributes for [`a[up-modal]`](/a.up-modal) will be honored.

  Emits events [`up:modal:open`](/up:modal:open) and [`up:modal:opened`](/up:modal:opened).

  @function up.modal.follow
  @param {Element|jQuery|string} linkOrSelector
    The link to follow.
  @param {string} [options.target]
    The selector to extract from the response and open in a modal dialog.
  @param {number} [options.width]
    The width of the dialog in pixels.
    By [default](/up.modal.config) the dialog will grow to fit its contents.
  @param {number} [options.height]
    The width of the dialog in pixels.
    By [default](/up.modal.config) the dialog will grow to fit its contents.
  @param {boolean} [options.sticky=false]
    If set to `true`, the modal remains
    open even it changes the page in the background.
  @param {boolean} [config.closable=true]
    When `true`, the modal will render a close icon and close when the user
    clicks on the backdrop or presses Escape.

    When `false`, you need to either supply an element with `[up-close]` or
    close the modal manually with `up.modal.close()`.
  @param {string} [options.confirm]
    A message that will be displayed in a cancelable confirmation dialog
    before the modal is being opened.
  @param {string} [options.method="GET"]
    Override the request method.
  @param {boolean} [options.history=true]
    Whether to add a browser history entry for the modal's source URL.
  @param {string} [options.animation]
    The animation to use when opening the modal.
  @param {number} [options.duration]
    The duration of the animation. See [`up.animate()`](/up.animate).
  @param {number} [options.delay]
    The delay before the animation starts. See [`up.animate()`](/up.animate).
  @param {string} [options.easing]
    The timing function that controls the animation's acceleration. [`up.animate()`](/up.animate).
  @return {Promise}
    A promise that will be fulfilled when the modal has been loaded and
    the opening animation has completed.
  @stable
  ###
  followAsap = (linkOrSelector, options) ->
    options = u.options(options)
    options.$link = $(linkOrSelector)
    openAsap(options)

  ###*
  Opens a modal for the given URL.

  \#\#\# Example

      up.modal.visit('/foo', { target: '.list' });

  This will request `/foo`, extract the `.list` selector from the response
  and open the selected container in a modal dialog.

  Emits events [`up:modal:open`](/up:modal:open) and [`up:modal:opened`](/up:modal:opened).

  @function up.modal.visit
  @param {string} url
    The URL to load.
  @param {string} options.target
    The CSS selector to extract from the response.
    The extracted content will be placed into the dialog window.
  @param {Object} options
    See options for [`up.modal.follow()`](/up.modal.follow).
  @return {Promise}
    A promise that will be fulfilled when the modal has been loaded and the opening
    animation has completed.
  @stable
  ###
  visitAsap = (url, options) ->
    options = u.options(options)
    options.url = url
    openAsap(options)

  ###*
  [Extracts](/up.extract) the given CSS selector from the given HTML string and
  opens the results in a modal.

  \#\#\# Example

      var html = 'before <div class="content">inner</div> after';
      up.modal.extract('.content', html);

  The would open a modal with the following contents:

      <div class="content">inner</div>

  Emits events [`up:modal:open`](/up:modal:open) and [`up:modal:opened`](/up:modal:opened).

  @function up.modal.extract
  @param {string} selector
    The CSS selector to extract from the HTML.
  @param {string} html
    The HTML containing the modal content.
  @param {Object} options
    See options for [`up.modal.follow()`](/up.modal.follow).
  @return {Promise}
    A promise that will be fulfilled when the modal has been opened and the opening
    animation has completed.
  @stable
  ###
  extractAsap = (selector, html, options) ->
    options = u.options(options)
    options.html = html
    options.history = u.option(options.history, false)
    options.target = selector
    openAsap(options)

  openAsap = (options) ->
    chain.asap closeNow, (-> openNow(options))

  openNow = (options) ->
    options = u.options(options)
    $link = u.option(u.pluckKey(options, '$link'), u.nullJQuery())
    url = u.option(u.pluckKey(options, 'url'), $link.attr('up-href'), $link.attr('href'))
    html = u.option(u.pluckKey(options, 'html'))
    target = u.option(u.pluckKey(options, 'target'), $link.attr('up-modal'), 'body')
    options.flavor = u.option(options.flavor, $link.attr('up-flavor'), config.flavor)
    options.position = u.option(options.position, $link.attr('up-position'), flavorDefault('position', options.flavor))
    options.position = u.evalOption(options.position, $link: $link)
    options.width = u.option(options.width, $link.attr('up-width'), flavorDefault('width', options.flavor))
    options.maxWidth = u.option(options.maxWidth, $link.attr('up-max-width'), flavorDefault('maxWidth', options.flavor))
    options.height = u.option(options.height, $link.attr('up-height'), flavorDefault('height'))
    options.animation = u.option(options.animation, $link.attr('up-animation'), flavorDefault('openAnimation', options.flavor))
    options.animation = u.evalOption(options.animation, position: options.position)
    options.backdropAnimation = u.option(options.backdropAnimation, $link.attr('up-backdrop-animation'), flavorDefault('backdropOpenAnimation', options.flavor))
    options.backdropAnimation = u.evalOption(options.backdropAnimation, position: options.position)
    options.sticky = u.option(options.sticky, u.castedAttr($link, 'up-sticky'), flavorDefault('sticky', options.flavor))
    options.closable = u.option(options.closable, u.castedAttr($link, 'up-closable'), flavorDefault('closable', options.flavor))
    options.confirm = u.option(options.confirm, $link.attr('up-confirm'))
    options.method = up.link.followMethod($link, options)
    options.layer = 'modal'
    options.failLayer = u.option(options.failLayer, $link.attr('up-fail-layer'), 'auto')
    animateOptions = up.motion.animateOptions(options, $link, duration: flavorDefault('openDuration', options.flavor), easing: flavorDefault('openEasing', options.flavor))

    # Although we usually fall back to full page loads if a browser doesn't support pushState,
    # in the case of modals we assume that the developer would rather see a dialog
    # without an URL update.
    options.history = u.option(options.history, u.castedAttr($link, 'up-history'), flavorDefault('history', options.flavor))
    options.history = false unless up.browser.canPushState()

    up.browser.whenConfirmed(options).then ->
      up.bus.whenEmitted('up:modal:open', url: url, message: 'Opening modal').then ->
        state.phase = 'opening'
        state.flavor = options.flavor
        state.sticky = options.sticky
        state.closable = options.closable
        state.position = options.position
        if options.history
          state.coveredUrl = up.browser.url()
          state.coveredTitle = document.title
        options.provideTarget = -> createHiddenFrame(target, options)
        extractOptions = u.merge(options, animation: false)
        if html
          promise = up.extract(target, html, extractOptions)
        else
          promise = up.replace(target, url, extractOptions)
        promise = promise.then ->
          shiftElements()
          unveilFrame()
          animate(options.animation, options.backdropAnimation, animateOptions)
        promise = promise.then ->
          state.phase = 'opened'
          up.emit('up:modal:opened', message: 'Modal opened')
        promise

  ###*
  This event is [emitted](/up.emit) when a modal dialog is starting to open.

  @event up:modal:open
  @param event.preventDefault()
    Event listeners may call this method to prevent the modal from opening.
  @stable
  ###

  ###*
  This event is [emitted](/up.emit) when a modal dialog has finished opening.

  @event up:modal:opened
  @stable
  ###

  ###*
  Closes a currently opened modal overlay.

  Does nothing if no modal is currently open.

  Emits events [`up:modal:close`](/up:modal:close) and [`up:modal:closed`](/up:modal:closed).

  @function up.modal.close
  @param {Object} options
    See options for [`up.animate()`](/up.animate)
  @return {Promise}
    A promise that will be fulfilled once the modal's close
    animation has finished.
  @stable
  ###
  closeAsap = (options) ->
    chain.asap -> closeNow(options)

  closeNow = (options) ->
    unless isOpen() # this can happen when a request fails and the chain proceeds to the next task
      return Promise.resolve()

    options = u.options(options)
    viewportCloseAnimation = u.option(options.animation, flavorDefault('closeAnimation'))
    viewportCloseAnimation = u.evalOption(viewportCloseAnimation, position: state.position)
    backdropCloseAnimation = u.option(options.backdropAnimation, flavorDefault('backdropCloseAnimation'))
    backdropCloseAnimation = u.evalOption(backdropCloseAnimation, position: state.position)
    animateOptions = up.motion.animateOptions(options, duration: flavorDefault('closeDuration'), easing: flavorDefault('closeEasing'))

    destroyOptions = u.options(
      u.except(options, 'animation', 'duration', 'easing', 'delay'),
      history: state.coveredUrl,
      title: state.coveredTitle
    )

    up.bus.whenEmitted('up:modal:close', $element: state.$modal, message: 'Closing modal').then ->
      state.phase = 'closing'
      # the current URL must be deleted *before* calling up.destroy,
      # since up.feedback listens to up:fragment:destroyed and then
      # re-assigns .up-current classes.
      state.url = null
      state.coveredUrl = null
      state.coveredTitle = null

      promise = animate(viewportCloseAnimation, backdropCloseAnimation, animateOptions)

      promise = promise.then ->
        up.destroy(state.$modal, destroyOptions)

      promise = promise.then ->
        unshiftElements()
        state.phase = 'closed'
        state.$modal = null
        state.flavor = null
        state.sticky = null
        state.closable = null
        state.position = null
        up.emit('up:modal:closed', message: 'Modal closed')

      promise

  markAsAnimating = (isAnimating = true) ->
    state.$modal?.toggleClass('up-modal-animating', isAnimating)

  animate = (viewportAnimation, backdropAnimation, animateOptions) ->
    # If we're not animating the dialog, don't animate the backdrop either
    if up.motion.isNone(viewportAnimation)
      Promise.resolve()
    else
      markAsAnimating()
      promise = Promise.all([
        up.animate(state.$modal.find('.up-modal-viewport'), viewportAnimation, animateOptions),
        up.animate(state.$modal.find('.up-modal-backdrop'), backdropAnimation, animateOptions)
      ])
      promise = promise.then -> markAsAnimating(false)
      promise

  ###*
  This event is [emitted](/up.emit) when a modal dialog
  is starting to [close](/up.modal.close).

  @event up:modal:close
  @param event.preventDefault()
    Event listeners may call this method to prevent the modal from closing.
  @stable
  ###

  ###*
  This event is [emitted](/up.emit) when a modal dialog
  is done [closing](/up.modal.close).

  @event up:modal:closed
  @stable
  ###

  autoclose = ->
    unless state.sticky
      discardHistory()
      closeAsap()

  ###*
  Returns whether the given element or selector is contained
  within the current modal.

  @function up.modal.contains
  @param {string} elementOrSelector
    The element to test
  @return {boolean}
  @stable
  ###
  contains = (elementOrSelector) ->
    $element = $(elementOrSelector)
    $element.closest('.up-modal').length > 0

  flavor = (name, overrideConfig = {}) ->
    up.log.warn 'The up.modal.flavor function is deprecated. Use the up.modal.flavors property instead.'
    u.assign(flavorOverrides(name), overrideConfig)

  ###*
  Returns a config object for the given flavor.
  Properties in that config should be preferred to the defaults in
  [`/up.modal.config`](/up.modal.config).

  @function flavorOverrides
  @internal
  ###
  flavorOverrides = (flavor) ->
    flavors[flavor] ||= {}

  ###*
  Returns the config option for the current flavor.

  @function flavorDefault
  @internal
  ###
  flavorDefault = (key, flavorName = state.flavor) ->
    value = flavorOverrides(flavorName)[key] if flavorName
    value = config[key] if u.isMissing(value)
    value

  ###*
  Clicking this link will load the destination via AJAX and open
  the given selector in a modal dialog.

  \#\#\# Example

      <a href="/blogs" up-modal=".blog-list">Switch blog</a>

  Clicking would request the path `/blog` and select `.blog-list` from
  the HTML response. Unpoly will dim the page
  and place the matching `.blog-list` tag will be placed in
  a modal dialog.

  @selector [up-modal]
  @param {string} up-modal
    The CSS selector that will be extracted from the response and displayed in a modal dialog.
  @param {string} [up-confirm]
    A message that will be displayed in a cancelable confirmation dialog
    before the modal is opened.
  @param {string} [up-method='GET']
    Override the request method.
  @param {string} [up-sticky]
    If set to `"true"`, the modal remains
    open even if the page changes in the background.
  @param {boolean} [up-closable]
    When `true`, the modal will render a close icon and close when the user
    clicks on the backdrop or presses Escape.

    When `false`, you need to either supply an element with `[up-close]` or
    close the modal manually with `up.modal.close()`.
  @param {string} [up-animation]
    The animation to use when opening the viewport containing the dialog.
  @param {string} [up-backdrop-animation]
    The animation to use when opening the backdrop that dims the page below the dialog.
  @param {string} [up-height]
    The width of the dialog in pixels.
    By [default](/up.modal.config) the dialog will grow to fit its contents.
  @param {string} [up-width]
    The width of the dialog in pixels.
    By [default](/up.modal.config) the dialog will grow to fit its contents.
  @param {string} [up-history]
    Whether to push an entry to the browser history for the modal's source URL.

    Set this to `'false'` to prevent the URL bar from being updated.
    Set this to a URL string to update the history with the given URL.

  @stable
  ###
  up.link.onAction '[up-modal]',
    # Don't just pass the `follow` function reference so we can stub it in tests
    ($link, options) -> followAsap($link, options)

  # Close the modal when someone clicks outside the dialog (but not on a modal opener).
  # Note that we cannot listen to clicks on .up-modal-backdrop, which is a sister element
  # of .up-modal-viewport. Since the user will effectively click on the viewport, not
  # the backdrop, backdrop will not receive a bubbling event.
  up.on('click', '.up-modal', (event) ->
    return unless state.closable

    $target = $(event.target)
    unless $target.closest('.up-modal-dialog').length || $target.closest('[up-modal]').length
      up.bus.consumeAction(event)
      closeAsap()
  )

  up.on('up:fragment:inserted', (event, $fragment) ->
    if contains($fragment)
      if newSource = $fragment.attr('up-source')
        state.url = newSource
    else if contains(event.origin) && !up.popup.contains($fragment)
      autoclose()
  )

  # Close the pop-up overlay when the user presses ESC.
  up.bus.onEscape ->
    closeAsap() if state.closable

  ###*
  When this element is clicked, closes a currently open dialog.

  Does nothing if no modal is currently open.

  To make a link that closes the current modal, but follows to
  a fallback destination if no modal is open:

      <a href="/fallback" up-close>Okay</a>

  @selector .up-modal [up-close]
  @stable
  ###
  up.on('click', '.up-modal [up-close]', (event, $element) ->
    closeAsap()
    # If the user closes the modal by clicking on the background, we want to halt the event chain here.
    # The event should not trigger anything else. The user needs to click again for another interaction.
    # Also only prevent the default when we actually closed a modal.
    # This way we can have buttons that close a modal when within a modal, but link to a destination if not.
    up.bus.consumeAction(event)
  )

  ###*
  Clicking this link will load the destination via AJAX and open
  the given selector in a modal drawer that slides in from the edge of the screen.

  You can configure drawers using the [`up.modal.flavors.drawer`](/up.modal.flavors.drawer) property.

  \#\#\# Example

      <a href="/blogs" up-drawer=".blog-list">Switch blog</a>

  Clicking would request the path `/blog` and select `.blog-list` from
  the HTML response. Unpoly will dim the page
  and place the matching `.blog-list` tag will be placed in
  a modal drawer.

  @selector [up-drawer]
  @param {string} up-drawer
    The CSS selector to extract from the response and open in the drawer.
  @param {string} [up-position='auto']
    The side from which the drawer slides in.

    Valid values are `'left'`, `'right'` and `'auto'`. If set to `'auto'`, the
    drawer will slide in from left if the opening link is on the left half of the screen.
    Otherwise it will slide in from the right.
  @stable
  ###
  up.macro '[up-drawer]', ($link) ->
    target = $link.attr('up-drawer')
    $link.attr
      'up-modal': target
      'up-flavor': 'drawer'

  ###*
  Sets default options for future drawers.

  @property up.modal.flavors.drawer
  @param {Object} config
    Default options for future drawers.

    See [`up.modal.config`] for available options.
  @experimental
  ###
  flavors.drawer =
    openAnimation: (options) ->
      switch options.position
        when 'left' then 'move-from-left'
        when 'right' then 'move-from-right'
    closeAnimation: (options) ->
      switch options.position
        when 'left' then 'move-to-left'
        when 'right' then 'move-to-right'
    position: (options) ->
      if u.isPresent(options.$link)
        u.horizontalScreenHalf(options.$link)
      else
        # In case the drawer was opened programmatically through Javascript,
        # we might now know the link that was clicked on.
        'left'

  # When the user uses the back button we will usually restore <body> or a base container.
  # We close any open modal because it probably won't match the restored state.
  up.on 'up:history:restore', closeAsap

  # The framework is reset between tests
  up.on 'up:framework:reset', reset

  knife: eval(Knife?.point)
  visit: visitAsap
  follow: followAsap
  extract: extractAsap
  close: closeAsap
  url: -> state.url
  coveredUrl: -> state.coveredUrl
  config: config
  flavors: flavors
  contains: contains
  isOpen: isOpen
  flavor: flavor # deprecated

)(jQuery)
