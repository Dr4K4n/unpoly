#= require ./record

u = up.util

class up.Request extends up.Record

  fields: ->
    ['method', 'url', 'data', 'target', 'failTarget', 'headers', 'timeout']

  constructor: (options) ->
    super(options)
    @method = u.normalizeMethod(options.method)
    @headers ||= {}
    @extractHashFromUrl()
    if @data && !u.methodAllowsPayload(@method) && !u.isFormData(@data)
      @transferDataToUrl()

  extractHashFromUrl: =>
    urlParts = u.parseUrl(@url)
    # Remember the #hash for later revealing.
    # It will be lost during normalization.
    @hash = urlParts.hash
    @url = u.normalizeUrl(urlParts, hash: false)

  transferDataToUrl: =>
    # GET methods are not allowed to have a payload, so we transfer { data } params to the URL.
    query = u.requestDataAsQuery(@data)
    separator = if u.contains(@url, '?') then '&' else '?'
    @url += separator + query
    # Now that we have transfered the params into the URL, we delete them from the { data } option.
    @data = undefined

  isIdempotent: =>
    up.proxy.isIdempotentMethod(@method)

  send: =>
    # We will modify this request below.
    # This would confuse API clients and cache key logic in up.proxy.
    new Promise (resolve, reject) =>
      xhr = new XMLHttpRequest()

      xhrHeaders = u.copy(@headers)
      xhrData = @data
      xhrMethod = @method
      xhrUrl = @url

      [xhrMethod, xhrData] = up.proxy.wrapMethod(xhrMethod, xhrData)

      if u.isFormData(xhrData)
        delete xhrHeaders['Content-Type'] # let the browser set the content type
      else if u.isPresent(xhrData)
        xhrData = u.requestDataAsQuery(xhrData, purpose: 'form')
        xhrHeaders['Content-Type'] = 'application/x-www-form-urlencoded'
      else
        # XMLHttpRequest expects null for an empty body
        xhrData = null

      xhrHeaders[up.protocol.config.targetHeader] = @target if @target
      xhrHeaders[up.protocol.config.failTargetHeader] = @failTarget if @failTarget

      if csrfToken = @csrfToken()
        xhrHeaders[up.protocol.config.csrfHeader] = csrfToken

      xhr.open(xhrMethod, xhrUrl)

      for header, value of xhrHeaders
        xhr.setRequestHeader(header, value)

      # Convert from XHR API to promise API
      resolveWithResponse = =>
        response = @buildResponse(xhr)
        if response.isSuccess()
          resolve(response)
        else
          reject(response)

      xhr.onload = resolveWithResponse
      xhr.onerror = resolveWithResponse
      xhr.ontimeout = resolveWithResponse

      xhr.timeout = @timeout if @timeout

      xhr.send(xhrData)

  replacePage: =>
    $form = $('<form class="up-page-loader"></form>')

    addField = (field) -> $('<input type="hidden">').attr(field).appendTo($form)

    if @method == 'GET'
      formMethod = 'GET'
    else
      # Browser forms can only have GET or POST methods.
      # When we want to make a request with another method, most backend
      # frameworks allow to pass the method as a param.
      addField(name: up.protocol.config.methodParam, value: @method)
      formMethod = 'POST'

    $form.attr(method: formMethod, action: @url)

    if csrfToken = @csrfToken()
      addField(name: up.protocol.config.csrfParam, value: csrfToken)

    u.each u.requestDataAsArray(@data), addField

    $form.hide().appendTo('body')
    up.browser.submitForm($form)

  # Returns a csrfToken if this request requires it
  csrfToken: =>
    if !@isIdempotent() && !u.isCrossDomain(@url)
      up.protocol.csrfToken()

  buildResponse: (xhr) =>
    responseAttrs =
      method: @method
      url: @url
      text: xhr.responseText
      status: xhr.status
      request: @
      xhr: xhr

    if urlFromServer = up.protocol.locationFromXhr(xhr)
      responseAttrs.url = urlFromServer
      # If the server changes a URL, it is expected to signal a new method as well.
      responseAttrs.method = up.protocol.methodFromXhr(xhr) ? 'GET'

    new up.Response(responseAttrs)

  isCachable: =>
    @isIdempotent() && !u.isFormData(@data)

  cacheKey: =>
    [@url, @method, u.requestDataAsQuery(@data), @target].join('|')

  @normalize: (object) ->
    if object instanceof @
      # This object has gone through instantiation and normalization before.
      object
    else
      new @(object)
