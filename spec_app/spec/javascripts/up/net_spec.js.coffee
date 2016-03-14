describe 'up.net', ->

  u = up.util

  describe 'Javascript functions', ->

    beforeEach ->
      jasmine.clock().install()
      jasmine.clock().mockDate()

    describe 'up.ajax', ->

      it 'caches server responses for 5 minutes', ->
        responses = []

        # Send the same request for the same path, 3 minutes apart
        up.ajax(url: '/foo').then (data) -> responses.push(data)
        jasmine.clock().tick(3 * 60 * 1000)
        up.ajax(url: '/foo').then (data) -> responses.push(data)

        # See that only a single network request was triggered
        expect(jasmine.Ajax.requests.count()).toEqual(1)
        expect(responses).toEqual([])

        @respondWith('foo')

        # See that both requests have been fulfilled by the same response
        expect(responses).toEqual(['foo', 'foo'])

        # Send another request after another 3 minutes
        # The clock is now a total of 6 minutes after the first request,
        # exceeding the cache's retention time of 5 minutes.
        jasmine.clock().tick(3 * 60 * 1000)
        up.ajax(url: '/foo').then (data) -> responses.push(data)

        # See that we have triggered a second request
        expect(jasmine.Ajax.requests.count()).toEqual(2)

        @respondWith('bar')

        expect(responses).toEqual(['foo', 'foo', 'bar'])

      it "doesn't reuse responses when asked for the same path, but different selectors", ->
        up.ajax(url: '/path', target: '.a')
        up.ajax(url: '/path', target: '.b')
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
          expect(up.net.config.wrapMethods).toBePresent()

#        beforeEach ->
#          @oldWrapMethod = up.net.config.wrapMethod
#          up.net.config.wrapMethod = true
#
#        afterEach ->
#          up.net.config.wrapMethod = @oldWrapMetod

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
          @oldMaxRequests = up.net.config.maxRequests
          up.net.config.maxRequests = 1

        afterEach ->
          up.net.config.maxRequests = @oldMaxRequests

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
          up.net.config.slowDelay = 0
          @events = []
          u.each ['up:net:load', 'up:net:received', 'up:net:slow', 'up:net:recover'], (eventName) =>
            up.on eventName, =>
              @events.push eventName

        it 'emits an up:net:slow event once the proxy started loading, and up:net:recover if it is done loading', ->
  
          up.ajax(url: '/foo')
  
          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow'
          ])
  
          up.ajax(url: '/bar')
  
          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow',
            'up:net:load'
          ])
  
          jasmine.Ajax.requests.at(0).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'foo'
  
          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow',
            'up:net:load',
            'up:net:received'
          ])
  
          jasmine.Ajax.requests.at(1).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'bar'
  
          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow',
            'up:net:load',
            'up:net:received',
            'up:net:received',
            'up:net:recover'
          ])
  
        it 'does not emit an up:net:slow event if preloading', ->

          # A request for preloading preloading purposes
          # doesn't make us busy.
          up.ajax(url: '/foo', preload: true)
          expect(@events).toEqual([
            'up:net:load'
          ])
          expect(up.net.isBusy()).toBe(false)

          # The same request with preloading does make us busy.
          up.ajax(url: '/foo')
          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow'
          ])
          expect(up.net.isBusy()).toBe(true)

          # The response resolves both promises and makes
          # the proxy idle again.
          jasmine.Ajax.requests.at(0).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'foo'
          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow',
            'up:net:received',
            'up:net:recover'
          ])
          expect(up.net.isBusy()).toBe(false)

        it 'can delay the up:net:slow event to prevent flickering of spinners', ->
          up.net.config.slowDelay = 100

          up.ajax(url: '/foo')
          expect(@events).toEqual([
            'up:net:load'
          ])

          jasmine.clock().tick(50)
          expect(@events).toEqual([
            'up:net:load'
          ])

          jasmine.clock().tick(50)
          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow'
          ])

          jasmine.Ajax.requests.at(0).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'foo'

          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow',
            'up:net:received',
            'up:net:recover'
          ])

        it 'does not emit up:net:recover if a delayed up:net:slow was never emitted due to a fast response', ->
          up.net.config.slowDelay = 100

          up.ajax(url: '/foo')
          expect(@events).toEqual([
            'up:net:load'
          ])

          jasmine.clock().tick(50)

          jasmine.Ajax.requests.at(0).respondWith
            status: 200
            contentType: 'text/html'
            responseText: 'foo'

          jasmine.clock().tick(100)

          expect(@events).toEqual([
            'up:net:load',
            'up:net:received'
          ])

        it 'emits up:net:recover if a request returned but failed', ->

          up.ajax(url: '/foo')

          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow'
          ])

          jasmine.Ajax.requests.at(0).respondWith
            status: 500
            contentType: 'text/html'
            responseText: 'something went wrong'

          expect(@events).toEqual([
            'up:net:load',
            'up:net:slow',
            'up:net:received',
            'up:net:recover'
          ])


    describe 'up.net.preload', ->

      describeCapability 'canPushState', ->

        it "loads and caches the given link's destination", ->
          $link = affix('a[href="/path"]')
          up.net.preload($link)
          expect(u.isPromise(up.net.get(url: '/path'))).toBe(true)

        it "does not load a link whose method has side-effects", ->
          $link = affix('a[href="/path"][data-method="post"]')
          up.net.preload($link)
          expect(up.net.get(url: '/path')).toBeUndefined()

      describeFallback 'canPushState', ->

        it "does nothing", ->
          $link = affix('a[href="/path"]')
          up.net.preload($link)
          expect(jasmine.Ajax.requests.count()).toBe(0)

    describe 'up.net.get', ->

      it 'should have tests'

    describe 'up.net.set', ->

      it 'should have tests'

    describe 'up.net.alias', ->

      it 'uses an existing cache entry for another request (used in case of redirects)'

    describe 'up.net.clear', ->

      it 'removes all cache entries'

  describe 'unobtrusive behavior', ->

    describe '[up-preload]', ->

      it 'preloads the link destination on mouseover, after a delay'

      it 'triggers a separate AJAX request with a short cache expiry when hovered multiple times', (done) ->
        up.net.config.cacheExpiry = 10
        up.net.config.preloadDelay = 0
        spyOn(up, 'follow')
        $element = affix('a[href="/foo"][up-preload]')
        Trigger.mouseover($element)
        @setTimer 1, =>
          expect(up.follow.calls.count()).toBe(1)
          @setTimer 16, =>
            Trigger.mouseover($element)
            @setTimer 1, =>
              expect(up.follow.calls.count()).toBe(2)
              done()
