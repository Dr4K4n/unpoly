describe 'up.proxy', ->

  u = up.util

  describe 'JavaScript functions', ->

    describe 'up.ajax', ->

      it 'makes a request with the given URL and params', ->
        up.ajax('/foo', data: { key: 'value' }, method: 'post')
        request = @lastRequest()
        expect(request.url).toMatchUrl('/foo')
        expect(request.data()).toEqual(key: ['value'])
        expect(request.method).toEqual('POST')

      it 'also allows to pass the URL as a { url } option instead', ->
        up.ajax(url: '/foo', data: { key: 'value' }, method: 'post')
        request = @lastRequest()
        expect(request.url).toMatchUrl('/foo')
        expect(request.data()).toEqual(key: ['value'])
        expect(request.method).toEqual('POST')

      it 'submits the replacement targets as HTTP headers, so the server may choose to only frender the requested fragments', asyncSpec (next) ->
        up.ajax(url: '/foo', target: '.target', failTarget: '.fail-target')

        next =>
          request = @lastRequest()
          expect(request.requestHeaders['X-Up-Target']).toEqual('.target')
          expect(request.requestHeaders['X-Up-Fail-Target']).toEqual('.fail-target')

      it 'resolves to a Response object that contains information about the response and request', (done) ->
        promise = up.ajax(
          url: '/url'
          data: { key: 'value' }
          method: 'post'
          target: '.target'
        )

        u.nextFrame =>
          @respondWith(
            status: 201,
            responseText: 'response-text'
          )

          promise.then (response) ->
            expect(response.request.url).toMatchUrl('/url')
            expect(response.request.data).toEqual(key: 'value')
            expect(response.request.method).toEqual('POST')
            expect(response.request.target).toEqual('.target')
            expect(response.request.hash).toBeBlank()

            expect(response.url).toMatchUrl('/url') # If the server signaled a redirect with X-Up-Location, this would be reflected here
            expect(response.method).toEqual('POST') # If the server sent a X-Up-Method header, this would be reflected here
            expect(response.text).toEqual('response-text')
            expect(response.status).toEqual(201)
            expect(response.xhr).toBePresent()

            done()

      it "preserves the URL hash in a separate { hash } property, since although it isn't sent to server, code might need it to process the response", (done) ->
        promise = up.ajax('/url#hash')

        u.nextFrame =>
          request = @lastRequest()
          expect(request.url).toMatchUrl('/url')

          @respondWith('response-text')

          promise.then (response) ->
            expect(response.request.url).toMatchUrl('/url')
            expect(response.request.hash).toEqual('#hash')
            expect(response.url).toMatchUrl('/url')
            done()

      describe 'when the server responds with an X-Up-Method header', ->

        it 'updates the { method } property in the response object', (done) ->
          promise = up.ajax(
            url: '/url'
            data: { key: 'value' }
            method: 'post'
            target: '.target'
          )

          u.nextFrame =>
            @respondWith(
              responseHeaders:
                'X-Up-Location': '/redirect'
                'X-Up-Method': 'GET'
            )

            promise.then (response) ->
              expect(response.request.url).toMatchUrl('/url')
              expect(response.request.method).toEqual('POST')
              expect(response.url).toMatchUrl('/redirect')
              expect(response.method).toEqual('GET')
              done()

      describe 'when the server responds with an X-Up-Location header', ->

        it 'sets the { url } property on the response object', (done) ->
          promise = up.ajax('/request-url#request-hash')

          u.nextFrame =>
            @respondWith
              responseHeaders:
                'X-Up-Location': '/response-url'

            promise.then (response) ->
              expect(response.request.url).toMatchUrl('/request-url')
              expect(response.request.hash).toEqual('#request-hash')
              expect(response.url).toMatchUrl('/response-url')
              done()

        it 'considers a redirection URL an alias for the requested URL', asyncSpec (next) ->
          up.ajax('/foo')

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseHeaders:
                'X-Up-Location': '/bar'
                'X-Up-Method': 'GET'

          next =>
            up.ajax('/bar')

          next =>
            # See that the cached alias is used and no additional requests are made
            expect(jasmine.Ajax.requests.count()).toEqual(1)

        it 'does not considers a redirection URL an alias for the requested URL if the original request was never cached', asyncSpec (next) ->
          up.ajax('/foo', method: 'post') # POST requests are not cached

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseHeaders:
                'X-Up-Location': '/bar'
                'X-Up-Method': 'GET'

          next =>
            up.ajax('/bar')

          next =>
            # See that an additional request was made
            expect(jasmine.Ajax.requests.count()).toEqual(2)

        it 'does not considers a redirection URL an alias for the requested URL if the response returned a non-200 status code', asyncSpec (next) ->
          up.ajax('/foo')

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseHeaders:
                'X-Up-Location': '/bar'
                'X-Up-Method': 'GET'
              status: 500

          next =>
            up.ajax('/bar')

          next =>
            # See that an additional request was made
            expect(jasmine.Ajax.requests.count()).toEqual(2)

        it "does not explode if the original request's { data } is a FormData object", asyncSpec (next) ->
          up.ajax('/foo', method: 'post', data: new FormData()) # POST requests are not cached

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseHeaders:
                'X-Up-Location': '/bar'
                'X-Up-Method': 'GET'

          next =>
            @secondAjaxPromise = up.ajax('/bar')

          next.await =>
            promiseState2(@secondAjaxPromise).then (result) ->
              # See that the promise was not rejected due to an internal error.
              expect(result.state).toEqual('pending')

      describe 'CSRF', ->

        beforeEach ->
          up.protocol.config.csrfHeader = 'csrf-header'
          up.protocol.config.csrfToken = 'csrf-token'

        it 'sets a CSRF token in the header', asyncSpec (next) ->
          up.proxy.ajax('/path', method: 'post')
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['csrf-header']).toEqual('csrf-token')

        it 'does not add a CSRF token if there is none', asyncSpec (next) ->
          up.protocol.config.csrfToken = ''
          up.proxy.ajax('/path', method: 'post')
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['csrf-header']).toBeMissing()

        it 'does not add a CSRF token for GET requests', asyncSpec (next) ->
          up.proxy.ajax('/path', method: 'get')
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['csrf-header']).toBeMissing()

        it 'does not add a CSRF token when loading content from another domain', asyncSpec (next) ->
          up.proxy.ajax('http://other-domain.tld/path', method: 'post')
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['csrf-header']).toBeMissing()

      describe 'with { data } option', ->

        it "uses the given params as a non-GET request's payload", asyncSpec (next) ->
          givenParams = { 'foo-key': 'foo-value', 'bar-key': 'bar-value' }
          up.ajax(url: '/path', method: 'put', data: givenParams)

          next =>
            expect(@lastRequest().data()['foo-key']).toEqual(['foo-value'])
            expect(@lastRequest().data()['bar-key']).toEqual(['bar-value'])

        it "encodes the given params into the URL of a GET request", (done) ->
          givenParams = { 'foo-key': 'foo-value', 'bar-key': 'bar-value' }
          promise = up.ajax(url: '/path', method: 'get', data: givenParams)

          u.nextFrame =>
            expect(@lastRequest().url).toMatchUrl('/path?foo-key=foo-value&bar-key=bar-value')
            expect(@lastRequest().data()).toBeBlank()

            @respondWith('response-text')

            promise.then (response) ->
              # See that the response object has been updated by moving the data options
              # to the URL. This is important for up.dom code that works on response.request.
              expect(response.request.url).toMatchUrl('/path?foo-key=foo-value&bar-key=bar-value')
              expect(response.request.data).toBeBlank()
              done()

      it 'caches server responses for the configured duration', asyncSpec (next) ->
        up.proxy.config.cacheExpiry = 200 # 1 second for test

        responses = []
        trackResponse = (response) -> responses.push(response.text)

        next =>
          up.ajax(url: '/foo').then(trackResponse)
          expect(jasmine.Ajax.requests.count()).toEqual(1)

        next.after (10), =>
          # Send the same request for the same path
          up.ajax(url: '/foo').then(trackResponse)

          # See that only a single network request was triggered
          expect(jasmine.Ajax.requests.count()).toEqual(1)
          expect(responses).toEqual([])

        next =>
          # Server responds once.
          @respondWith('foo')

        next =>
          # See that both requests have been fulfilled
          expect(responses).toEqual(['foo', 'foo'])

        next.after (200), =>
          # Send another request after another 3 minutes
          # The clock is now a total of 6 minutes after the first request,
          # exceeding the cache's retention time of 5 minutes.
          up.ajax(url: '/foo').then(trackResponse)

          # See that we have triggered a second request
          expect(jasmine.Ajax.requests.count()).toEqual(2)

        next =>
          @respondWith('bar')

        next =>
          expect(responses).toEqual(['foo', 'foo', 'bar'])

      it "does not cache responses if config.cacheExpiry is 0", asyncSpec (next) ->
        up.proxy.config.cacheExpiry = 0
        next => up.ajax(url: '/foo')
        next => up.ajax(url: '/foo')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "does not cache responses if config.cacheSize is 0", asyncSpec (next) ->
        up.proxy.config.cacheSize = 0
        next => up.ajax(url: '/foo')
        next => up.ajax(url: '/foo')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it 'does not limit the number of cache entries if config.cacheSize is undefined'

      it 'never discards old cache entries if config.cacheExpiry is undefined'

      it 'respects a config.cacheSize setting', asyncSpec (next) ->
        up.proxy.config.cacheSize = 2
        next => up.ajax(url: '/foo')
        next => up.ajax(url: '/bar')
        next => up.ajax(url: '/baz')
        next => up.ajax(url: '/foo')
        next => expect(jasmine.Ajax.requests.count()).toEqual(4)

      it "doesn't reuse responses when asked for the same path, but different selectors", asyncSpec (next) ->
        next => up.ajax(url: '/path', target: '.a')
        next => up.ajax(url: '/path', target: '.b')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "doesn't reuse responses when asked for the same path, but different params", asyncSpec (next) ->
        next => up.ajax(url: '/path', data: { query: 'foo' })
        next => up.ajax(url: '/path', data: { query: 'bar' })
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "reuses a response for an 'html' selector when asked for the same path and any other selector", asyncSpec (next) ->
        next => up.ajax(url: '/path', target: 'html')
        next => up.ajax(url: '/path', target: 'body')
        next => up.ajax(url: '/path', target: 'p')
        next => up.ajax(url: '/path', target: '.klass')
        next => expect(jasmine.Ajax.requests.count()).toEqual(1)

      it "reuses a response for a 'body' selector when asked for the same path and any other selector other than 'html'", asyncSpec (next) ->
        next => up.ajax(url: '/path', target: 'body')
        next => up.ajax(url: '/path', target: 'p')
        next => up.ajax(url: '/path', target: '.klass')
        next => expect(jasmine.Ajax.requests.count()).toEqual(1)

      it "doesn't reuse a response for a 'body' selector when asked for the same path but an 'html' selector", asyncSpec (next) ->
        next => up.ajax(url: '/path', target: 'body')
        next => up.ajax(url: '/path', target: 'html')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "doesn't reuse responses for different paths", asyncSpec (next) ->
        next => up.ajax(url: '/foo')
        next => up.ajax(url: '/bar')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      u.each ['GET', 'HEAD', 'OPTIONS'], (method) ->

        it "caches #{method} requests", asyncSpec (next) ->
          next => up.ajax(url: '/foo', method: method)
          next => up.ajax(url: '/foo', method: method)
          next => expect(jasmine.Ajax.requests.count()).toEqual(1)

        it "does not cache #{method} requests with { cache: false }", asyncSpec (next) ->
          next => up.ajax(url: '/foo', method: method, cache: false)
          next => up.ajax(url: '/foo', method: method, cache: false)
          next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      u.each ['POST', 'PUT', 'DELETE'], (method) ->

        it "does not cache #{method} requests", asyncSpec (next) ->
          next => up.ajax(url: '/foo', method: method)
          next => up.ajax(url: '/foo', method: method)
          next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it 'does not cache responses with a non-200 status code', asyncSpec (next) ->
        next => up.ajax(url: '/foo')
        next => @respondWith(status: 500, contentType: 'text/html', responseText: 'foo')
        next => up.ajax(url: '/foo')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      describe 'with config.wrapMethods set', ->

        it 'should be set by default', ->
          expect(up.proxy.config.wrapMethods).toBePresent()

        u.each ['GET', 'POST', 'HEAD', 'OPTIONS'], (method) ->

          it "does not change the method of a #{method} request", asyncSpec (next) ->
            up.ajax(url: '/foo', method: method)

            next =>
              request = @lastRequest()
              expect(request.method).toEqual(method)
              expect(request.data()['_method']).toBeUndefined()

        u.each ['PUT', 'PATCH', 'DELETE'], (method) ->

          it "turns a #{method} request into a POST request and sends the actual method as a { _method } param to prevent unexpected redirect behavior (https://makandracards.com/makandra/38347)", asyncSpec (next) ->
            up.ajax(url: '/foo', method: method)

            next =>
              request = @lastRequest()
              expect(request.method).toEqual('POST')
              expect(request.data()['_method']).toEqual([method])

      describe 'with config.maxRequests set', ->

        beforeEach ->
          @oldMaxRequests = up.proxy.config.maxRequests
          up.proxy.config.maxRequests = 1

        afterEach ->
          up.proxy.config.maxRequests = @oldMaxRequests

        it 'limits the number of concurrent requests', asyncSpec (next) ->
          responses = []
          trackResponse = (response) -> responses.push(response.text)

          next =>
            up.ajax(url: '/foo').then(trackResponse)
            up.ajax(url: '/bar').then(trackResponse)

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1) # only one request was made

          next =>
            @respondWith('first response', request: jasmine.Ajax.requests.at(0))

          next =>
            expect(responses).toEqual ['first response']
            expect(jasmine.Ajax.requests.count()).toEqual(2) # a second request was made

          next =>
            @respondWith('second response', request: jasmine.Ajax.requests.at(1))

          next =>
            expect(responses).toEqual ['first response', 'second response']

        it 'ignores preloading for the request limit', asyncSpec (next) ->
          next => up.ajax(url: '/foo', preload: true)
          next => up.ajax(url: '/bar')
          next => expect(jasmine.Ajax.requests.count()).toEqual(2)
          next => up.ajax(url: '/bar')
          next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      describe 'events', ->

        beforeEach ->
          up.proxy.config.slowDelay = 0
          @events = []
          u.each ['up:proxy:load', 'up:proxy:loaded', 'up:proxy:slow', 'up:proxy:recover'], (eventName) =>
            up.on eventName, =>
              @events.push eventName

        it 'does not emit an up:proxy:slow event if preloading', (next) ->
          next =>
            # A request for preloading preloading purposes
            # doesn't make us busy.
            up.ajax(url: '/foo', preload: true)

          next =>
            expect(@events).toEqual([
              'up:proxy:load'
            ])
            expect(up.proxy.isBusy()).toBe(false)

          next =>
            # The same request with preloading does trigger up:proxy:slow.
            up.ajax(url: '/foo')

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow'
            ])
            expect(up.proxy.isBusy()).toBe(true)

          next =>
            # The response resolves both promises and makes
            # the proxy idle again.
            jasmine.Ajax.requests.at(0).respondWith
              status: 200
              contentType: 'text/html'
              responseText: 'foo'

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow',
              'up:proxy:loaded',
              'up:proxy:recover'
            ])
            expect(up.proxy.isBusy()).toBe(false)

        it 'can delay the up:proxy:slow event to prevent flickering of spinners', asyncSpec (next) ->
          next =>
            up.proxy.config.slowDelay = 100
            up.ajax(url: '/foo')

          next =>
            expect(@events).toEqual([
              'up:proxy:load'
            ])

          next.after 50, =>
            expect(@events).toEqual([
              'up:proxy:load'
            ])

          next.after 60, =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow'
            ])

          next =>
            jasmine.Ajax.requests.at(0).respondWith
              status: 200
              contentType: 'text/html'
              responseText: 'foo'

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow',
              'up:proxy:loaded',
              'up:proxy:recover'
            ])

        it 'does not emit up:proxy:recover if a delayed up:proxy:slow was never emitted due to a fast response', asyncSpec (next) ->
          next =>
            up.proxy.config.slowDelay = 100
            up.ajax(url: '/foo')

          next =>
            expect(@events).toEqual([
              'up:proxy:load'
            ])

          next.after 50, =>
            jasmine.Ajax.requests.at(0).respondWith
              status: 200
              contentType: 'text/html'
              responseText: 'foo'

          next.after 150, =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:loaded'
            ])

        it 'emits up:proxy:recover if a request returned but failed', asyncSpec (next) ->
          next =>
            up.ajax(url: '/foo')

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow'
            ])

          next =>
            jasmine.Ajax.requests.at(0).respondWith
              status: 500
              contentType: 'text/html'
              responseText: 'something went wrong'

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow',
              'up:proxy:loaded',
              'up:proxy:recover'
            ])


    describe 'up.proxy.preload', ->

      describeCapability 'canPushState', ->

        it "loads and caches the given link's destination", asyncSpec (next) ->
          affix('.target')
          $link = affix('a[href="/path"][up-target=".target"]')

          up.proxy.preload($link)

          next =>
            cachedPromise = up.proxy.get(url: '/path', target: '.target')
            expect(u.isPromise(cachedPromise)).toBe(true)

        it "does not load a link whose method has side-effects", asyncSpec (next) ->
          $link = affix('a[href="/path"][data-method="post"]')
          up.proxy.preload($link)

          next => expect(up.proxy.get(url: '/path')).toBeUndefined()

        describe 'X-Up-Target header', ->

          beforeEach ->
            @requestTarget = => @lastRequest().requestHeaders['X-Up-Target']

          it 'includes the [up-target] selector', asyncSpec (next) ->
            affix('.target')
            $link = affix('a[href="/path"][up-target=".target"]')
            up.proxy.preload($link)
            next => expect(@requestTarget()).toEqual('.target')

          it 'replaces the [up-target] selector with a fallback if the targeted element is not currently on the page', asyncSpec (next) ->
            $link = affix('a[href="/path"][up-target=".target"]')
            up.proxy.preload($link)
            # The default fallback would usually be `body`, but in Jasmine specs we change
            # it to protect the test runner during failures.
            next => expect(@requestTarget()).toEqual('.default-fallback')

          it 'includes the [up-modal] selector and does not replace it with a fallback', asyncSpec (next) ->
            $link = affix('a[href="/path"][up-modal=".target"]')
            up.proxy.preload($link)
            next => expect(@requestTarget()).toEqual('.target')

          it 'includes the [up-popup] selector and does not replace it with a fallback', asyncSpec (next) ->
            $link = affix('a[href="/path"][up-popup=".target"]')
            up.proxy.preload($link)
            next => expect(@requestTarget()).toEqual('.target')

      describeFallback 'canPushState', ->

        it "does nothing", asyncSpec (next) ->
          affix('.target')
          $link = affix('a[href="/path"][up-target=".target"]')
          up.proxy.preload($link)
          next =>
            expect(jasmine.Ajax.requests.count()).toBe(0)

    describe 'up.proxy.get', ->

      it 'returns an existing cache entry for the given request', ->
        promise1 = up.ajax(url: '/foo', data: { key: 'value' })
        promise2 = up.proxy.get(url: '/foo', data: { key: 'value' })
        expect(promise1).toBe(promise2)

      it 'returns undefined if the given request is not cached', ->
        promise = up.proxy.get(url: '/foo', data: { key: 'value' })
        expect(promise).toBeUndefined()

      it "returns undefined if the given request's { data } is a FormData object", ->
        promise = up.proxy.get(url: '/foo', data: new FormData())
        expect(promise).toBeUndefined()

    describe 'up.proxy.set', ->

      it 'should have tests'

    describe 'up.proxy.alias', ->

      it 'uses an existing cache entry for another request (used in case of redirects)'

    describe 'up.proxy.clear', ->

      it 'removes all cache entries'

  describe 'unobtrusive behavior', ->

    describe '[up-preload]', ->

      it 'preloads the link destination on mouseover, after a delay'

      it 'triggers a separate AJAX request when hovered multiple times and the cache expires between hovers', asyncSpec (next)  ->
        up.proxy.config.cacheExpiry = 20
        up.proxy.config.preloadDelay = 0
        $element = affix('a[href="/foo"][up-preload]')
        Trigger.mouseover($element)

        next.after 1, =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)

        next.after 1, =>
          Trigger.mouseover($element)

        next.after 1, =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)

        next.after 20, =>
          Trigger.mouseover($element)

        next.after 1, =>
          expect(jasmine.Ajax.requests.count()).toEqual(2)
