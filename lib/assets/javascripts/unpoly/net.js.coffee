###*
Caching and preloading
======================

All HTTP requests go through the Unpoly proxy.
It caches a [limited](/up.net.config) number of server responses
for a [limited](/up.net.config) amount of time,
making requests to these URLs return insantly.
  
The cache is cleared whenever the user makes a non-`GET` request
(like `POST`, `PUT` or `DELETE`).

The proxy can also used to speed up reaction times by [preloading
links when the user hovers over the click area](/up-preload) (or puts the mouse/finger
down before releasing). This way the response will already be cached when
the user performs the click.

Spinners
--------

You can [listen](/up.on) to the [`up:net:slow`](/up:net:slow)
and [`up:net:recover`](/up:net:recover) events  to implement a spinner
that appears during a long-running request,
and disappears once the response has been received:

    <div class="spinner">Please wait!</div>

Here is the Javascript to make it alive:

    up.compiler('.spinner', function($element) {

      show = function() { $element.show() };
      hide = function() { $element.hide() };

      showOff = up.on('up:net:slow', show);
      hideOff = up.on('up:net:recover', hide);

      hide();

      // Clean up when the element is removed from the DOM
      return function() {
        showOff();
        hideOff();
      };

    });

The `up:net:slow` event will be emitted after a delay of 300 ms
to prevent the spinner from flickering on and off.
You can change (or remove) this delay by [configuring `up.net`](/up.net.config) like this:

    up.net.config.slowDelay = 150;

@class up.net
###
up.net = (($) ->

  u = up.util

  $waitingLink = undefined
  preloadDelayTimer = undefined
  slowDelayTimer = undefined
  pendingCount = undefined
  slowEventEmitted = undefined

  queuedRequests = []

  ###*
  @property up.net.config
  @param {Number} [config.preloadDelay=75]
    The number of milliseconds to wait before [`[up-preload]`](/up-preload)
    starts preloading.
  @param {Number} [config.cacheSize=70]
    The maximum number of responses to cache.
    If the size is exceeded, the oldest items will be dropped from the cache.
  @param {Number} [config.cacheExpiry=300000]
    The number of milliseconds until a cache entry expires.
    Defaults to 5 minutes.
  @param {Number} [config.slowDelay=300]
    How long the proxy waits until emitting the [`up:net:slow` event](/up:net:slow).
    Use this to prevent flickering of spinners.
  @param {Number} [config.maxRequests=4]
    The maximum number of concurrent requests to allow before additional
    requests are queued. This currently ignores preloading requests.

    You might find it useful to set this to `1` in full-stack integration
    tests (e.g. Selenium).

    Note that your browser might [impose its own request limit](http://www.browserscope.org/?category=network)
    regardless of what you configure here.
  @param {Array<String>} [config.wrapMethods]
    An array of uppercase HTTP method names. AJAX requests with one of these methods
    will be converted into a `POST` request and carry their original method as a `_method`
    parameter. This is to [prevent unexpected redirect behavior](https://makandracards.com/makandra/38347).
  @param {String} [config.wrapMethodParam]
    The name of the POST parameter when wrapping HTTP methods in a `POST` request.
  @param {Array<String>} [config.safeMethods]
    An array of uppercase HTTP method names that are considered idempotent.
    The proxy cache will only cache idempotent requests and will clear the entire
    cache after a non-idempotent request.
  @stable
  ###
  config = u.config
    slowDelay: 300
    preloadDelay: 75
    cacheSize: 70
    cacheExpiry: 1000 * 60 * 5
    maxRequests: 4
    wrapMethods: ['PATCH', 'PUT', 'DELETE']
    wrapMethodParam: '_method'
    safeMethods: ['GET', 'OPTIONS', 'HEAD']

  cacheKey = (request) ->
    normalizeRequest(request)
    [ request.url,
      request.method,
      request.data,
      request.target
    ].join('|')

  cache = u.cache
    size: -> config.cacheSize
    expiry: -> config.cacheExpiry
    key: cacheKey
    # log: 'up.net'

  ###*
  Returns a cached response for the given request.

  Returns `undefined` if the given request is not currently cached.

  @function up.net.get
  @return {Promise}
    A promise for the response that is API-compatible with the
    promise returned by [`jQuery.ajax`](http://api.jquery.com/jquery.ajax/).
  @experimental
  ###
  get = (request) ->
    request = normalizeRequest(request)
    candidates = [request]
    unless request.target is 'html'
      requestForHtml = u.merge(request, target: 'html')
      candidates.push(requestForHtml)
      unless request.target is 'body'
        requestForBody = u.merge(request, target: 'body')
        candidates.push(requestForBody)
    for candidate in candidates
      if response = cache.get(candidate)
        return response

  ###*
  Manually stores a promise for the response to the given request.

  @function up.net.set
  @param {String} request.url
  @param {String} [request.method='GET']
  @param {String} [request.target='body']
  @param {Promise} response
    A promise for the response that is API-compatible with the
    promise returned by [`jQuery.ajax`](http://api.jquery.com/jquery.ajax/).
  @experimental
  ###
  set = cache.set

  ###*
  Manually removes the given request from the cache.

  You can also [configure](/up.net.config) when the proxy
  automatically removes cache entries.

  @function up.net.remove
  @param {String} request.url
  @param {String} [request.method='GET']
  @param {String} [request.target='body']
  @experimental
  ###
  remove = cache.remove

  ###*
  Removes all cache entries.

  Unpoly also automatically clears the cache whenever it processes
  a request with a non-GET HTTP method.

  @function up.net.clear
  @stable
  ###
  clear = cache.clear

  cancelPreloadDelay = ->
    clearTimeout(preloadDelayTimer)
    preloadDelayTimer = null

  cancelBusyDelay = ->
    clearTimeout(slowDelayTimer)
    slowDelayTimer = null

  reset = ->
    $waitingLink = null
    cancelPreloadDelay()
    cancelBusyDelay()
    pendingCount = 0
    config.reset()
    slowEventEmitted = false
    cache.clear()
    queuedRequests = []

  reset()

  alias = cache.alias

  normalizeRequest = (request) ->
    unless request._normalized
      request.method = u.normalizeMethod(request.method)
      request.url = u.normalizeUrl(request.url) if request.url
      request.target ||= 'body'
      request._normalized = true
    request

  ###*
  Makes a request to the given URL and caches the response.
  If the response was already cached, returns the HTML instantly.
  
  If requesting a URL that is not read-only, the response will
  not be cached and the entire cache will be cleared.
  Only requests with a method of `GET`, `OPTIONS` and `HEAD`
  are considered to be read-only.

  If a network connection is attempted, the proxy will emit
  a `up:net:load` event with the `request` as its argument.
  Once the response is received, a `up:net:receive` event will
  be emitted.
  
  @function up.ajax
  @param {String} request.url
  @param {String} [request.method='GET']
  @param {String} [request.target='body']
  @param {Boolean} [request.cache]
    Whether to use a cached response, if available.
    If set to `false` a network connection will always be attempted.
  @param {Object} [request.headers={}]
    An object of additional header key/value pairs to send along
    with the request.
  @param {Object} [request.data={}]
    An object of request parameters.
  @return
    A promise for the response that is API-compatible with the
    promise returned by [`jQuery.ajax`](http://api.jquery.com/jquery.ajax/).
  @stable
  ###
  ajax = (options) ->

    forceCache = (options.cache == true)
    ignoreCache = (options.cache == false)

    request = u.only(options, 'url', 'method', 'data', 'target', 'headers', '_normalized')
    request = normalizeRequest(request)

    pending = true

    # Non-GET requests always touch the network
    # unless `options.cache` is explicitly set to `true`.
    # These requests are never cached.
    if !isIdempotent(request) && !forceCache
      clear()
      promise = loadOrQueue(request)
    # If we have an existing promise matching this new request,
    # we use it unless `options.cache` is explicitly set to `false`.
    # The promise might still be pending.
    else if (promise = get(request)) && !ignoreCache
      up.puts 'Re-using cached response for %s %s', request.method, request.url
      pending = (promise.state() == 'pending')
    # If no existing promise is available, we make a network request.
    else
      promise = loadOrQueue(request)
      set(request, promise)
      # Don't cache failed requests
      promise.fail -> remove(request)

    if pending && !options.preload
      # This might actually make `pendingCount` higher than the actual
      # number of outstanding requests. However, we need to cover the
      # following case:
      #
      # - User starts preloading a request.
      #   This triggers *no* `up:net:slow`.
      # - User starts loading the request (without preloading).
      #   This triggers `up:net:slow`.
      # - The request finishes.
      #   This triggers `up:net:recover`.
      loadStarted()
      promise.always(loadEnded)

    console.groupEnd()

    promise

  ###*
  Returns `true` if the proxy is not currently waiting
  for a request to finish. Returns `false` otherwise.

  @function up.net.isIdle
  @return {Boolean}
    Whether the proxy is idle
  @experimental
  ###
  isIdle = ->
    pendingCount == 0

  ###*
  Returns `true` if the proxy is currently waiting
  for a request to finish. Returns `false` otherwise.

  @function up.net.isBusy
  @return {Boolean}
    Whether the proxy is busy
  @experimental
  ###
  isBusy = ->
    pendingCount > 0

  loadStarted = ->
    wasIdle = isIdle()
    pendingCount += 1
    if wasIdle
      # Since the emission of up:net:slow might be delayed by config.slowDelay,
      # we wrap the mission in a function for scheduling below.
      emission = ->
        if isBusy() # a fast response might have beaten the delay
          up.emit('up:net:slow', message: 'Proxy is busy')
          slowEventEmitted = true
      if config.slowDelay > 0
        slowDelayTimer = setTimeout(emission, config.slowDelay)
      else
        emission()

  ###*
  This event is [emitted]/(up.emit) when [AJAX requests](/up.ajax)
  are taking long to finish.

  By default Unpoly will wait 300 ms for an AJAX request to finish
  before emitting `up:net:slow`. You can configure this time like this:

      up.net.config.slowDelay = 150;

  Once all responses have been received, an [`up:net:recover`](/up:net:recover)
  will be emitted.

  Note that if additional requests are made while Unpoly is already busy
  waiting, **no** additional `up:net:slow` events will be triggered.

  @event up:net:slow
  @stable
  ###

  loadEnded = ->
    pendingCount -= 1
    if isIdle() && slowEventEmitted
      up.emit('up:net:recover', message: 'Proxy is idle')
      slowEventEmitted = false

  ###*
  This event is [emitted]/(up.emit) when [AJAX requests](/up.ajax)
  have [taken long to finish](/up:net:slow), but have finished now.

  @event up:net:recover
  @stable
  ###

  loadOrQueue = (request) ->
    if pendingCount < config.maxRequests
      load(request)
    else
      queue(request)

  queue = (request) ->
    up.puts('Queuing request for %s %s', request.method, request.url)
    deferred = $.Deferred()
    entry =
      deferred: deferred
      request: request
    queuedRequests.push(entry)
    deferred.promise()

  load = (request) ->
    up.emit('up:net:load', u.merge(request, message: ['Loading %s %s', request.method, request.url]))

    # We will modify the request below for features like method wrapping.
    # Let's not change the original request which would confuse API clients
    # and cache key logic.
    request = u.copy(request)

    request.headers ||= {}
    request.headers['X-Up-Target'] = request.target

    request.data = u.requestDataAsArray(request.data)

    if u.contains(config.wrapMethods, request.method)
      request.data.push
        name: config.wrapMethodParam
        value: request.method
      request.method = 'POST'

    promise = $.ajax(request)
    promise.done (data, textStatus, xhr) -> responseReceived(request, xhr)
    promise.fail (xhr, textStatus, errorThrown) -> responseReceived(request, xhr)
    promise

  responseReceived = (request, xhr) ->
    up.emit('up:net:received', u.merge(request, message: ['Server responded with %s %s (%d bytes)', xhr.status, xhr.statusText, xhr.responseText?.length]))
    pokeQueue()

  pokeQueue = ->
    if entry = queuedRequests.shift()
      promise = load(entry.request)
      promise.done (args...) -> entry.deferred.resolve(args...)
      promise.fail (args...) -> entry.deferred.reject(args...)

  ###*
  This event is [emitted]/(up.emit) before an [AJAX request](/up.ajax)
  is starting to load.

  @event up:net:load
  @param event.url
  @param event.method
  @param event.target
  @experimental
  ###

  ###*
  This event is [emitted]/(up.emit) when the response to an [AJAX request](/up.ajax)
  has been received.

  @event up:net:received
  @param event.url
  @param event.method
  @param event.target
  @experimental
  ###

  isIdempotent = (request) ->
    normalizeRequest(request)
    u.contains(config.safeMethods, request.method)

  checkPreload = ($link) ->
    delay = parseInt(u.presentAttr($link, 'up-delay')) || config.preloadDelay 
    unless $link.is($waitingLink)
      $waitingLink = $link
      cancelPreloadDelay()
      curriedPreload = ->
        preload($link)
        $waitingLink = null
      startPreloadDelay(curriedPreload, delay)
      
  startPreloadDelay = (block, delay) ->
    preloadDelayTimer = setTimeout(block, delay)

  ###*
  @function up.net.preload
  @param {String|Element|jQuery}
    The element whose destination should be preloaded.
  @return
    A promise that will be resolved when the request was loaded and cached
  @experimental
  ###
  preload = (linkOrSelector, options) ->
    $link = $(linkOrSelector)
    options = u.options(options)

    method = up.link.followMethod($link, options)
    if isIdempotent(method: method)
      up.log.group "Preloading link %o", $link, ->
        options.preload = true
        up.follow($link, options)
    else
      up.puts("Won't preload %o due to unsafe method %s", $link, method)
      u.resolvedPromise()

  ###*
  Links with an `up-preload` attribute will silently fetch their target
  when the user hovers over the click area, or when the user puts her
  mouse/finger down (before releasing). This way the
  response will already be cached when the user performs the click,
  making the interaction feel instant.   

  @selector [up-preload]
  @param [up-delay=75]
    The number of milliseconds to wait between hovering
    and preloading. Increasing this will lower the load in your server,
    but will also make the interaction feel less instant.
  @stable
  ###
  up.on 'mouseover mousedown touchstart', '[up-preload]', (event, $element) ->
    # Don't do anything if we are hovering over the child
    # of a link. The actual link will receive the event
    # and bubble in a second.
    unless up.link.childClicked(event, $element)
      checkPreload($element)

  up.on 'up:framework:reset', reset

  preload: preload
  ajax: ajax
  get: get
  alias: alias
  clear: clear
  remove: remove
  isIdle: isIdle
  isBusy: isBusy
  config: config
  defaults: -> u.error('up.net.defaults(...) no longer exists. Set values on he up.net.config property instead.')
  
)(jQuery)

up.ajax = up.net.ajax
