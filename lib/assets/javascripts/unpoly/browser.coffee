###*
Browser support
===============

Unpoly supports all modern browsers. It degrades gracefully with old versions of Internet Explorer:

IE11, Edge
: Full support

IE 10 or lower
: Unpoly prevents itself from booting itself, leaving you with a classic server-side application.


@class up.browser
###
up.browser = (($) ->

  u = up.util

  ###*
  @method up.browser.loadPage
  @param {string} url
  @param {string} [options.method='get']
  @param {Object|Array} [options.data]
  @internal
  ###
  loadPage = (url, options) ->
    options = u.options(options)
    method = u.normalizeMethod(options.method)
    if method == 'GET'
      query = u.requestDataAsQuery(options.data, purpose: 'url')
      url = "#{url}?#{query}" if query
      setLocationHref(url)
    else
      $form = $("<form method='POST' action='#{url}' class='up-page-loader'></form>")

      addField = (field) ->
        $field = $('<input type="hidden">').attr(field)
        $field.appendTo($form)

      # Since forms can only be GET or POST, and we're not making a GET,
      # we always add a method param
      addField(name: up.protocol.config.methodParam, value: method)

      if !u.isCrossDomain(url) && (csrfToken = up.protocol.csrfToken())
        addField(name: up.protocol.config.csrfParam, value: csrfToken)

      u.each u.requestDataAsArray(options.data), addField

      $form.hide().appendTo('body')
      submitForm($form)

  ###*
  For mocking in specs.

  @method submitForm
  ###
  submitForm = ($form) ->
    $form.submit()

  ###*
  For mocking in specs.

  @method setLocationHref
  ###
  setLocationHref = (url) ->
    location.href = url

  ###*
  A cross-browser way to interact with `console.log`, `console.error`, etc.

  This function falls back to `console.log` if the output stream is not implemented.
  It also prints substitution strings (e.g. `console.log("From %o to %o", "a", "b")`)
  as a single string if the browser console does not support substitution strings.

  \#\#\# Example

      up.browser.puts('log', 'Hi world');
      up.browser.puts('error', 'There was an error in %o', obj);

  @function up.browser.puts
  @internal
  ###
  puts = (stream, args...) ->
    console[stream](args...)

  CONSOLE_PLACEHOLDERS = /\%[odisf]/g

  stringifyArg = (arg) ->
    maxLength = 200
    closer = ''

    if u.isString(arg)
      string = arg.replace(/[\n\r\t ]+/g, ' ')
      string = string.replace(/^[\n\r\t ]+/, '')
      string = string.replace(/[\n\r\t ]$/, '')
      string = "\"#{string}\""
      closer = '"'
    else if u.isUndefined(arg)
      # JSON.stringify(undefined) is actually undefined
      string = 'undefined'
    else if u.isNumber(arg) || u.isFunction(arg)
      string = arg.toString()
    else if u.isArray(arg)
      string = "[#{u.map(arg, stringifyArg).join(', ')}]"
      closer = ']'
    else if u.isJQuery(arg)
      string = "$(#{u.map(arg, stringifyArg).join(', ')})"
      closer = ')'
    else if u.isElement(arg)
      $arg = $(arg)
      string = "<#{arg.tagName.toLowerCase()}"
      for attr in ['id', 'name', 'class']
        if value = $arg.attr(attr)
          string += " #{attr}=\"#{value}\""
      string += ">"
      closer = '>'
    else # object
      string = JSON.stringify(arg)
    if string.length > maxLength
      string = "#{string.substr(0, maxLength)} …"
      string += closer
    string

  ###*
  See https://developer.mozilla.org/en-US/docs/Web/API/Console#Using_string_substitutions

  @function up.browser.sprintf
  @internal
  ###
  sprintf = (message, args...) ->
    sprintfWithFormattedArgs(u.identity, message, args...)

  ###*
  @function up.browser.sprintfWithBounds
  @internal
  ###
  sprintfWithFormattedArgs = (formatter, message, args...) ->
    return '' if u.isBlank(message)

    i = 0
    message.replace CONSOLE_PLACEHOLDERS, ->
      arg = args[i]
      arg = formatter(stringifyArg(arg))
      i += 1
      arg

  url = ->
    location.href

  isIE10OrWorse = u.memoize ->
    !window.atob

  ###*
  Returns whether this browser supports manipulation of the current URL
  via [`history.pushState`](https://developer.mozilla.org/en-US/docs/Web/API/History/pushState).

  When `pushState`  (e.g. through [`up.follow()`](/up.follow)), it will gracefully
  fall back to a full page load.

  Note that Unpoly will not use `pushState` if the initial page was loaded with
  a request method other than GET.

  @function up.browser.canPushState
  @return {boolean}
  @experimental
  ###
  canPushState = ->
    # We cannot use pushState if the initial request method is a POST for two reasons:
    #
    # 1. Unpoly replaces the initial state so it can handle the pop event when the
    #    user goes back to the initial URL later. If the initial request was a POST,
    #    Unpoly will wrongly assumed that it can restore the state by reloading with GET.
    #
    # 2. Some browsers have a bug where the initial request method is used for all
    #    subsequently pushed states. That means if the user reloads the page on a later
    #    GET state, the browser will wrongly attempt a POST request.
    #    This issue affects Safari 9 and 10 (last tested in 2017-08).
    #    Modern Firefoxes, Chromes and IE10+ don't have this behavior.
    #
    # The way that we work around this is that we don't support pushState if the
    # initial request method was anything other than GET (but allow the rest of the
    # Unpoly framework to work). This way Unpoly will fall back to full page loads until
    # the framework was booted from a GET request.
    u.isDefined(history.pushState) && up.protocol.initialRequestMethod() == 'get'

  ###*
  Returns whether this browser supports animation using
  [CSS transitions](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Transitions).

  When Unpoly is asked to animate history on a browser that doesn't support
  CSS transitions (e.g. through [`up.animate()`](/up.animate)), it will skip the
  animation by instantly jumping to the last frame.

  @function up.browser.canCssTransition
  @return {boolean}
  @internal
  ###
  canCssTransition = ->
    'transition' of document.documentElement.style

  ###*
  Returns whether this browser supports the DOM event [`input`](https://developer.mozilla.org/de/docs/Web/Events/input).

  @function up.browser.canInputEvent
  @return {boolean}
  @internal
  ###
  canInputEvent = ->
    'oninput' of document.createElement('input')

  ###*
  Returns whether this browser supports promises.

  @function up.browser.canPromise
  @return {boolean}
  @internal
  ###
  canPromise = ->
    !!window.Promise

  ###*
  Returns whether this browser supports the [`FormData`](https://developer.mozilla.org/en-US/docs/Web/API/FormData)
  interface.

  @function up.browser.canFormData
  @return {boolean}
  @experimental
  ###
  canFormData = ->
    !!window.FormData

  ###*
  Returns whether this browser supports the [`DOMParser`](https://developer.mozilla.org/en-US/docs/Web/API/DOMParser)
  interface.

  @function up.browser.canDOMParser
  @return {boolean}
  @internal
  ###
  canDOMParser = ->
    !!window.DOMParser

  ###*
  Returns whether this browser supports the [`debugging console`](https://developer.mozilla.org/en-US/docs/Web/API/Console).

  @function up.browser.canConsole
  @return {boolean}
  @internal
  ###
  canConsole = ->
    window.console &&
      console.debug &&
      console.info &&
      console.warn &&
      console.error &&
      console.group &&
      console.groupCollapsed &&
      console.groupEnd

  isRecentJQuery = ->
    version = $.fn.jquery
    parts = version.split('.')
    major = parseInt(parts[0])
    minor = parseInt(parts[1])
    # When updating minimum jQuery, also update the dependency in package.json.
    major >= 2 || (major == 1 && minor >= 9)

  ###*
  Returns and deletes a cookie with the given name
  Inspired by Turbolinks: https://github.com/rails/turbolinks/blob/83d4b3d2c52a681f07900c28adb28bc8da604733/lib/assets/javascripts/turbolinks.coffee#L292

  @function up.browser.popCookie
  @internal
  ###
  popCookie = (name) ->
    value = document.cookie.match(new RegExp(name+"=(\\w+)"))?[1]
    if u.isPresent(value)
      document.cookie = name + '=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/'
    value

  ###*
  @function up,browser.whenConfirmed
  @return {Promise}
  @param {string} options.confirm
  @param {boolean} options.preload
  @internal
  ###
  whenConfirmed = (options) ->
    if options.preload || u.isBlank(options.confirm) || window.confirm(options.confirm)
      Promise.resolve()
    else
      u.unresolvablePromise()

  ###*
  Returns whether Unpoly supports the current browser.

  If this returns `false` Unpoly will prevent itself from [booting](/up.boot)
  and ignores all registered [event handlers](/up.on) and [compilers](/up.compiler).
  This leaves you with a classic server-side application.
  This is usually a better fallback than loading incompatible Javascript and causing
  many errors on load.

  @function up.browser.isSupported
  @stable
  ###
  isSupported = ->
    !isIE10OrWorse() &&
      isRecentJQuery() &&
      canConsole() &&
      # We don't require pushState in order to cater for Safari booting Unpoly with a non-GET method.
      # canPushState() &&
      canDOMParser() &&
      canFormData() &&
      canCssTransition() &&
      canInputEvent() &&
      canPromise()

  ###*
  @internal
  ###
  sessionStorage = u.memoize ->
    try
      # All supported browsers have sessionStorage, so we do not support
      # the case where window.sessionStorage is undefined.
      window.sessionStorage
    catch
      # Unfortunately Chrome explodes upon access of window.sessionStorage when
      # user blocks third-party cookies and site data and this page is embedded
      # as an <iframe>. See https://bugs.chromium.org/p/chromium/issues/detail?id=357625
      polyfilledSessionStorage()

  ###*
  @internal
  ###
  polyfilledSessionStorage = ->
    data = {}
    getItem: (prop) -> data[prop]
    setItem: (prop, value) -> data[prop] = value

  ###*
  Returns `'foo'` if the hash is `'#foo'`.

  Returns undefined if the hash is `'#'`, `''` or `undefined`.

  @function up.browser.hash
  @internal
  ###
  hash = (value) ->
    value ||= location.hash
    value ||= ''
    value = value.substr(1) if value[0] == '#'
    u.presence(value)


  knife: eval(Knife?.point)
  url: url
  loadPage: loadPage
  canPushState: canPushState
  whenConfirmed: whenConfirmed
  isSupported: isSupported
  puts: puts
  sprintf: sprintf
  sprintfWithFormattedArgs: sprintfWithFormattedArgs
  sessionStorage: sessionStorage
  popCookie: popCookie
  hash: hash
  isIE10OrWorse: isIE10OrWorse
  isRecentJQuery: isRecentJQuery
  canConsole:   canConsole
  canPushState: canPushState
  canDOMParser: canDOMParser
  canFormData: canFormData
  canCssTransition: canCssTransition
  canInputEvent: canInputEvent
  canPromise: canPromise


)(jQuery)

