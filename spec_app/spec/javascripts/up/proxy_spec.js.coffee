describe 'up.proxy', ->

  u = up.util

  describe 'JavaScript functions', ->

#    beforeEach ->
#      jasmine.clock().install()
#      jasmine.clock().mockDate()

    describe 'up.ajax', ->

      it 'makes a request with the given URL and params', ->
        up.ajax('/foo', data: { key: 'value' }, method: 'post')
        request = @lastRequest()
        expect(request.url).toEqualUrl('/foo')
        expect(request.data()).toEqual(key: ['value'])
        expect(request.method).toEqual('POST')

      it 'also allows to pass the URL as a { url } option instead', ->
        up.ajax(url: '/foo', data: { key: 'value' }, method: 'post')
        request = @lastRequest()
        expect(request.url).toEqualUrl('/foo')
        expect(request.data()).toEqual(key: ['value'])
        expect(request.method).toEqual('POST')

      it 'caches server responses for the 5 minutes', (done) ->

        responses = []
        trackResponse = (response) ->
          console.debug('Tracking response %s', response.body)
          responses.push(response.body)

        asyncSequence done, { mockTime: true }, (sequence) =>

          sequence.now =>
            up.ajax(url: '/foo').then(trackResponse)
            expect(jasmine.Ajax.requests.count()).toEqual(1)

          sequence.after (3 * 60 * 1000), =>
            # Send the same request for the same path
            up.ajax(url: '/foo').then(trackResponse)

            # See that only a single network request was triggered
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            expect(responses).toEqual([])

          sequence.next =>
            # Server responds once.
            @respondWith('foo')

          sequence.next =>
            # See that both requests have been fulfilled
            expect(responses).toEqual(['foo', 'foo'])

          sequence.after (3 * 60 * 1000), =>
            # Send another request after another 3 minutes
            # The clock is now a total of 6 minutes after the first request,
            # exceeding the cache's retention time of 5 minutes.
            up.ajax(url: '/foo').then(trackResponse)

            # See that we have triggered a second request
            expect(jasmine.Ajax.requests.count()).toEqual(2)

          sequence.next =>
            @respondWith('bar')

          sequence.next =>
            expect(responses).toEqual(['foo', 'foo', 'bar'])


      it "does not cache responses if config.cacheExpiry is 0", ->
        up.proxy.config.cacheExpiry = 0
        up.ajax(url: '/foo')
        up.ajax(url: '/foo')
        expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "does not cache responses if config.cacheSize is 0", ->
        up.proxy.config.cacheSize = 0
        up.ajax(url: '/foo')
        up.ajax(url: '/foo')
        expect(jasmine.Ajax.requests.count()).toEqual(2)

      it 'does not limit the number of cache entries if config.cacheSize is undefined'

      it 'never discards old cache entries if config.cacheExpiry is undefined'

      it 'respects a config.cacheSize setting', ->
        up.proxy.config.cacheSize = 2
        up.ajax(url: '/foo')
        up.ajax(url: '/bar')
        up.ajax(url: '/baz')
        up.ajax(url: '/foo')
        expect(jasmine.Ajax.requests.count()).toEqual(4)

      it "doesn't reuse responses when asked for the same path, but different selectors", ->
        up.ajax(url: '/path', target: '.a')
        up.ajax(url: '/path', target: '.b')
        expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "doesn't reuse responses when asked for the same path, but different params", ->
        up.ajax(url: '/path', data: { query: 'foo' })
        up.ajax(url: '/path', data: { query: 'bar' })
        expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "reuses a response for an 'html' selector when asked for the same path and any other selector", ->
        up.ajax(url: '/path', target: 'html')
        up.ajax(url: '/path', target: 'body')
        up.ajax(url: '/path', target: 'p')
        up.ajax(url: '/path', target: '.klass')
        expect(jasmine.Ajax.requests.count()).toEqual(1)

      it "reuses a response for a 'body' selector when asked for the same path and any other selector other than 'html'", ->
        up.ajax(url: '/path', target: 'body')
        up.ajax(url: '/path', target: 'p')
        up.ajax(url: '/path', target: '.klass')
        expect(jasmine.Ajax.requests.count()).toEqual(1)

      it "doesn't reuse a response for a 'body' selector when asked for the same path but an 'html' selector", ->
        up.ajax(url: '/path', target: 'body')
        up.ajax(url: '/path', target: 'html')
        expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "doesn't reuse responses for different paths", ->
        up.ajax(url: '/foo')
        up.ajax(url: '/bar')
        expect(jasmine.Ajax.requests.count()).toEqual(2)

      u.each ['GET', 'HEAD', 'OPTIONS'], (method) ->

        it "caches #{method} requests", ->
          u.times 2, -> up.ajax(url: '/foo', method: method)
          expect(jasmine.Ajax.requests.count()).toEqual(1)

        it "does not cache #{method} requests with cache: false option", ->
          u.times 2, -> up.ajax(url: '/foo', method: method, cache: false)
          expect(jasmine.Ajax.requests.count()).toEqual(2)

      u.each ['POST', 'PUT', 'DELETE'], (method) ->

        it "does not cache #{method} requests", ->
          u.times 2, -> up.ajax(url: '/foo', method: method)
          expect(jasmine.Ajax.requests.count()).toEqual(2)

        it "caches #{method} requests with cache: true option", ->
          u.times 2, -> up.ajax(url: '/foo', method: method, cache: true)
          expect(jasmine.Ajax.requests.count()).toEqual(1)

      it 'does not cache responses with a non-200 status code', ->
        # Send the same request for the same path, 3 minutes apart
        up.ajax(url: '/foo')

        @respondWith
          status: 500
          contentType: 'text/html'
          responseText: 'foo'

        up.ajax(url: '/foo')

        expect(jasmine.Ajax.requests.count()).toEqual(2)

      describe 'with config.wrapMethods set', ->

        it 'should be set by default', ->
          expect(up.proxy.config.wrapMethods).toBePresent()

#        beforeEach ->
#          @oldWrapMethod = up.proxy.config.wrapMethod
#          up.proxy.config.wrapMethod = true
#
#        afterEach ->
#          up.proxy.config.wrapMethod = @oldWrapMetod

        u.each ['GET', 'POST', 'HEAD', 'OPTIONS'], (method) ->

          it "does not change the method of a #{method} request", ->
            up.ajax(url: '/foo', method: method)
            request = @lastRequest()
            expect(request.method).toEqual(method)
            expect(request.data()['_method']).toBeUndefined()

        u.each ['PUT', 'PATCH', 'DELETE'], (method) ->

          it "turns a #{method} request into a POST request and sends the actual method as a { _method } param", ->
            up.ajax(url: '/foo', method: method)
            request = @lastRequest()
            expect(request.method).toEqual('POST')
            expect(request.data()['_method']).toEqual([method])

      describe 'with config.maxRequests set', ->

        beforeEach ->
          @oldMaxRequests = up.proxy.config.maxRequests
          up.proxy.config.maxRequests = 1

        afterEach ->
          up.proxy.config.maxRequests = @oldMaxRequests

        it 'limits the number of concurrent requests', ->
          responses = []
          up.ajax(url: '/foo').then (html) -> responses.push(html)
          up.ajax(url: '/bar').then (html) -> responses.push(html)
          expect(jasmine.Ajax.requests.count()).toEqual(1) # only one request was made
          @respondWith('first response', request: jasmine.Ajax.requests.at(0))
          expect(responses).toEqual ['first response']
          expect(jasmine.Ajax.requests.count()).toEqual(2) # a second request was made
          @respondWith('second response', request: jasmine.Ajax.requests.at(1))
          expect(responses).toEqual ['first response', 'second response']

#        it 'considers preloading links for the request limit', ->
#          up.ajax(url: '/foo', preload: true)
#          up.ajax(url: '/bar')
#          expect(jasmine.Ajax.requests.count()).toEqual(1)

      describe 'events', ->
        
        beforeEach ->
          up.proxy.config.slowDelay = 0
          @events = []
          u.each ['up:proxy:load', 'up:proxy:received', 'up:proxy:slow', 'up:proxy:recover'], (eventName) =>
            up.on eventName, =>
              @events.push eventName

        it 'emits an up:proxy:slow event once the proxy started loading, and up:proxy:recover if it is done loading', ->
  
          up.ajax(url: '/foo')
  
          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow'
          ])
  
          up.ajax(url: '/bar')
  
          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow',
            'up:proxy:load'
          ])
  
          jasmine.Ajax.requests.at(0).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'foo'
  
          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow',
            'up:proxy:load',
            'up:proxy:received'
          ])
  
          jasmine.Ajax.requests.at(1).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'bar'
  
          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow',
            'up:proxy:load',
            'up:proxy:received',
            'up:proxy:received',
            'up:proxy:recover'
          ])
  
        it 'does not emit an up:proxy:slow event if preloading', ->

          # A request for preloading preloading purposes
          # doesn't make us busy.
          up.ajax(url: '/foo', preload: true)
          expect(@events).toEqual([
            'up:proxy:load'
          ])
          expect(up.proxy.isBusy()).toBe(false)

          # The same request with preloading does make us busy.
          up.ajax(url: '/foo')
          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow'
          ])
          expect(up.proxy.isBusy()).toBe(true)

          # The response resolves both promises and makes
          # the proxy idle again.
          jasmine.Ajax.requests.at(0).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'foo'
          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow',
            'up:proxy:received',
            'up:proxy:recover'
          ])
          expect(up.proxy.isBusy()).toBe(false)

        it 'can delay the up:proxy:slow event to prevent flickering of spinners', ->
          up.proxy.config.slowDelay = 100

          up.ajax(url: '/foo')
          expect(@events).toEqual([
            'up:proxy:load'
          ])

          jasmine.clock().tick(50)
          expect(@events).toEqual([
            'up:proxy:load'
          ])

          jasmine.clock().tick(50)
          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow'
          ])

          jasmine.Ajax.requests.at(0).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'foo'

          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow',
            'up:proxy:received',
            'up:proxy:recover'
          ])

        it 'does not emit up:proxy:recover if a delayed up:proxy:slow was never emitted due to a fast response', ->
          up.proxy.config.slowDelay = 100

          up.ajax(url: '/foo')
          expect(@events).toEqual([
            'up:proxy:load'
          ])

          jasmine.clock().tick(50)

          jasmine.Ajax.requests.at(0).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'foo'

          jasmine.clock().tick(100)

          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:received'
          ])

        it 'emits up:proxy:recover if a request returned but failed', ->

          up.ajax(url: '/foo')

          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow'
          ])

          jasmine.Ajax.requests.at(0).respondWith
            status: 500
            contentType: 'text/html'
            responseText: 'something went wrong'

          expect(@events).toEqual([
            'up:proxy:load',
            'up:proxy:slow',
            'up:proxy:received',
            'up:proxy:recover'
          ])


    describe 'up.proxy.preload', ->

      describeCapability 'canPushState', ->

        it "loads and caches the given link's destination", ->
          $link = affix('a[href="/path"]')
          up.proxy.preload($link)
          expect(u.isPromise(up.proxy.get(url: '/path'))).toBe(true)

        it "does not load a link whose method has side-effects", ->
          $link = affix('a[href="/path"][data-method="post"]')
          up.proxy.preload($link)
          expect(up.proxy.get(url: '/path')).toBeUndefined()

      describeFallback 'canPushState', ->

        it "does nothing", ->
          $link = affix('a[href="/path"]')
          up.proxy.preload($link)
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

      it 'triggers a separate AJAX request with a short cache expiry when hovered multiple times', (done) ->
        up.proxy.config.cacheExpiry = 10
        up.proxy.config.preloadDelay = 0
        spyOn(up, 'follow')
        $element = affix('a[href="/foo"][up-preload]')
        Trigger.mouseover($element)
        u.setTimer 1, =>
          expect(up.follow.calls.count()).toBe(1)
          u.setTimer 16, =>
            Trigger.mouseover($element)
            u.setTimer 1, =>
              expect(up.follow.calls.count()).toBe(2)
              done()
