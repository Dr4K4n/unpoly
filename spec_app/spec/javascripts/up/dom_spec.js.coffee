describe 'up.dom', ->

  u = up.util
  
  describe 'JavaScript functions', ->

    describe 'up.replace', ->

      describeCapability 'canPushState', ->

        beforeEach ->

          @oldBefore = affix('.before').text('old-before')
          @oldMiddle = affix('.middle').text('old-middle')
          @oldAfter = affix('.after').text('old-after')

          @responseText =
            """
            <div class="before">new-before</div>
            <div class="middle">new-middle</div>
            <div class="after">new-after</div>
            """

          @respond = (options = {}) -> @respondWith(@responseText, options)

        it 'replaces the given selector with the same selector from a freshly fetched page', asyncSpec (next) ->
          up.replace('.middle', '/path')

          next =>
            @respond()

          next =>
            expect($('.before')).toHaveText('old-before')
            expect($('.middle')).toHaveText('new-middle')
            expect($('.after')).toHaveText('old-after')

        it 'returns a promise that will be resolved once the server response was received and the fragments were swapped', asyncSpec (next) ->
          resolution = jasmine.createSpy()
          promise = up.replace('.middle', '/path')
          promise.then(resolution)
          expect(resolution).not.toHaveBeenCalled()
          expect($('.middle')).toHaveText('old-middle')

          next =>
            @respond()

          next =>
            expect(resolution).toHaveBeenCalled()
            expect($('.middle')).toHaveText('new-middle')

        describe 'transitions', ->

          it 'returns a promise that will be resolved once the server response was received and the swap transition has completed', asyncSpec (next) ->
            resolution = jasmine.createSpy()
            promise = up.replace('.middle', '/path', transition: 'cross-fade', duration: 50)
            promise.then(resolution)
            expect(resolution).not.toHaveBeenCalled()
            expect($('.middle')).toHaveText('old-middle')

            next =>
              @respond()
              expect(resolution).not.toHaveBeenCalled()

            next.after 20, =>
              expect(resolution).not.toHaveBeenCalled()

            next.after 80, =>
              expect(resolution).toHaveBeenCalled()

          it 'ignores a { transition } option when replacing the body element', asyncSpec (next) ->
            up.dom.knife.mock('swapBody') # can't have the example replace the Jasmine test runner UI
            up.dom.knife.mock('destroy')  # if we don't swap the body, up.dom will destroy it
            replaceCallback = jasmine.createSpy()
            promise = up.replace('body', '/path', transition: 'cross-fade', duration: 50)
            promise.then(replaceCallback)
            expect(replaceCallback).not.toHaveBeenCalled()

            next =>
              @responseText = '<body>new text</body>'
              @respond()

            next =>
              expect(replaceCallback).toHaveBeenCalled()

        describe 'with { data } option', ->

          it "uses the given params as a non-GET request's payload", asyncSpec (next) ->
            givenParams = { 'foo-key': 'foo-value', 'bar-key': 'bar-value' }
            up.replace('.middle', '/path', method: 'put', data: givenParams)

            next =>
              expect(@lastRequest().data()['foo-key']).toEqual(['foo-value'])
              expect(@lastRequest().data()['bar-key']).toEqual(['bar-value'])

          it "encodes the given params into the URL of a GET request", asyncSpec (next) ->
            givenParams = { 'foo-key': 'foo-value', 'bar-key': 'bar-value' }
            up.replace('.middle', '/path', method: 'get', data: givenParams)
            next => expect(@lastRequest().url).toMatchUrl('/path?foo-key=foo-value&bar-key=bar-value')

        it 'uses a HTTP method given as { method } option', asyncSpec (next) ->
          up.replace('.middle', '/path', method: 'put')
          next => expect(@lastRequest()).toHaveRequestMethod('PUT')

        describe 'when the server responds with a non-200 status code', ->

          it 'replaces the first fallback instead of the given selector', asyncSpec (next) ->
            up.dom.config.fallbacks = ['.fallback']
            affix('.fallback')

            # can't have the example replace the Jasmine test runner UI
            extractSpy = up.dom.knife.mock('extract').and.returnValue(u.resolvedPromise())

            next => up.replace('.middle', '/path')
            next => @respond(status: 500)
            next => expect(extractSpy).toHaveBeenCalledWith('.fallback', jasmine.any(String), jasmine.any(Object))

          it 'uses a target selector given as { failTarget } option', asyncSpec (next) ->
            next =>
              up.replace('.middle', '/path', failTarget: '.after')

            next =>
              @respond(status: 500)

            next =>
              expect($('.middle')).toHaveText('old-middle')
              expect($('.after')).toHaveText('new-after')

          it 'rejects the returned promise', (done) ->
            affix('.after')
            promise = up.replace('.middle', '/path', failTarget: '.after')

            u.nextFrame =>
              promiseState promise, (state) =>
                expect(state).toEqual('pending')

                @respond(status: 500)

                u.nextFrame =>
                  promiseState promise, (state) =>
                    expect(state).toEqual('rejected')
                    done()

        describe 'when the request times out', ->

          it "doesn't crash and rejects the returned promise", (done) ->
            affix('.target')
            promise = up.replace('.middle', '/path', timeout: 25)

            u.nextFrame ->
              promiseState promise, (state) ->
                expect(state).toEqual('pending')
                u.setTimer 50, ->
                  promiseState promise, (state) ->
                    expect(state).toEqual('rejected')
                    done()

        describe 'when there is a network issue', ->

          it "doesn't crash and rejects the returned promise", (done) ->
            affix('.target')
            promise = up.replace('.middle', '/path')
            
            u.nextFrame =>
              promiseState promise, (state) =>
                expect(state).toEqual('pending')
                @lastRequest().responseError()
                u.nextFrame =>
                  promiseState promise, (state) =>
                    expect(state).toEqual('rejected')
                    done()

        describe 'history', ->

          it 'should set the browser location to the given URL', (done) ->
            promise = up.replace('.middle', '/path')
            @respond()
            promise.then ->
              expect(location.href).toMatchUrl('/path')
              done()

          it 'does not add a history entry after non-GET requests', asyncSpec (next) ->
            up.replace('.middle', '/path', method: 'post')
            next => @respond()
            next => expect(location.href).toMatchUrl(@hrefBeforeExample)

          it 'adds a history entry after non-GET requests if the response includes a { X-Up-Method: "get" } header (will happen after a redirect)', asyncSpec (next) ->
            up.replace('.middle', '/path', method: 'post')
            next => @respond(responseHeaders: { 'X-Up-Method': 'GET' })
            next => expect(location.href).toMatchUrl('/path')

          it 'does not a history entry after a failed GET-request', asyncSpec (next) ->
            up.replace('.middle', '/path', method: 'post', failTarget: '.middle')
            next => @respond(status: 500)
            next => expect(location.href).toMatchUrl(@hrefBeforeExample)

          it 'does not add a history entry with { history: false } option', asyncSpec (next) ->
            up.replace('.middle', '/path', history: false)
            next => @respond()
            next => expect(location.href).toMatchUrl(@hrefBeforeExample)

          it "detects a redirect's new URL when the server sets an X-Up-Location header", asyncSpec (next) ->
            up.replace('.middle', '/path')
            next => @respond(responseHeaders: { 'X-Up-Location': '/other-path' })
            next => expect(location.href).toMatchUrl('/other-path')

          it 'adds params from a { data } option to the URL of a GET request', asyncSpec (next) ->
            up.replace('.middle', '/path', data: { 'foo-key': 'foo value', 'bar-key': 'bar value' })
            next => @respond()
            next => expect(location.href).toMatchUrl('/path?foo-key=foo%20value&bar-key=bar%20value')

          describe 'if a URL is given as { history } option', ->

            it 'uses that URL as the new location after a GET request', asyncSpec (next) ->
              up.replace('.middle', '/path', history: '/given-path')
              next => @respond(failTarget: '.middle')
              next => expect(location.href).toMatchUrl('/given-path')

            it 'adds a history entry after a non-GET request', asyncSpec (next) ->
              up.replace('.middle', '/path', method: 'post', history: '/given-path')
              next => @respond(failTarget: '.middle')
              next => expect(location.href).toMatchUrl('/given-path')

            it 'does not add a history entry after a failed non-GET request', asyncSpec (next) ->
              up.replace('.middle', '/path', method: 'post', history: '/given-path', failTarget: '.middle')
              next => @respond(failTarget: '.middle', status: 500)
              next => expect(location.href).toMatchUrl(@hrefBeforeExample)

        describe 'source', ->

          it 'remembers the source the fragment was retrieved from', (done) ->
            promise = up.replace('.middle', '/path')
            @respond()
            promise.then ->
              expect($('.middle').attr('up-source')).toMatch(/\/path$/)
              done()

          it 'reuses the previous source for a non-GET request (since that is reloadable)', asyncSpec (next) ->
            @oldMiddle.attr('up-source', '/previous-source')
            up.replace('.middle', '/path', method: 'post')
            next =>
              @respond()
            next =>
              expect($('.middle')).toHaveText('new-middle')
              expect(up.dom.source('.middle')).toMatchUrl('/previous-source')

          describe 'if a URL is given as { source } option', ->

            it 'uses that URL as the source for a GET request', asyncSpec (next) ->
              up.replace('.middle', '/path', source: '/given-path')
              next => @respond()
              next => expect(up.dom.source('.middle')).toMatchUrl('/given-path')

            it 'uses that URL as the source after a non-GET request', asyncSpec (next) ->
              up.replace('.middle', '/path', method: 'post', source: '/given-path')
              next => @respond()
              next => expect(up.dom.source('.middle')).toMatchUrl('/given-path')

            it 'ignores the option and reuses the previous source after a failed non-GET request', asyncSpec (next) ->
              @oldMiddle.attr('up-source', '/previous-source')
              up.replace('.middle', '/path', method: 'post', source: '/given-path', failTarget: '.middle')
              next => @respond(status: 500)
              next => expect(up.dom.source('.middle')).toMatchUrl('/previous-source')

        describe 'document title', ->

          it "sets the document title to the response <title>", asyncSpec (next) ->
            affix('.container').text('old container text')
            up.replace('.container', '/path')

            next =>
              @respondWith """
                <html>
                  <head>
                    <title>Title from HTML</title>
                  </head>
                  <body>
                    <div class='container'>
                      new container text
                    </div>
                  </body>
                </html>
              """

            next =>
              expect($('.container')).toHaveText('new container text')
              expect(document.title).toBe('Title from HTML')

          it "sets the document title to an 'X-Up-Title' header in the response", asyncSpec (next) ->
            affix('.container').text('old container text')
            up.replace('.container', '/path')

            next =>
              @respondWith
                responseHeaders:
                  'X-Up-Title': 'Title from header'
                responseText: """
                  <div class='container'>
                    new container text
                  </div>
                  """

            next =>
              expect($('.container')).toHaveText('new container text')
              expect(document.title).toBe('Title from header')

          it "prefers the X-Up-Title header to the response <title>", asyncSpec (next) ->
            affix('.container').text('old container text')
            up.replace('.container', '/path')

            next =>
              @respondWith
                responseHeaders:
                  'X-Up-Title': 'Title from header'
                responseText: """
                  <html>
                    <head>
                      <title>Title from HTML</title>
                    </head>
                    <body>
                      <div class='container'>
                        new container text
                      </div>
                    </body>
                  </html>
                """

            next =>
              expect($('.container')).toHaveText('new container text')
              expect(document.title).toBe('Title from header')

          it "sets the document title to the response <title> with { history: false, title: true } options (bugfix)", asyncSpec (next) ->
            affix('.container').text('old container text')
            up.replace('.container', '/path', history: false, title: true)

            next =>
              @respondWith """
                <html>
                  <head>
                    <title>Title from HTML</title>
                  </head>
                  <body>
                    <div class='container'>
                      new container text
                    </div>
                  </body>
                </html>
              """

            next =>
              expect($('.container')).toHaveText('new container text')
              expect(document.title).toBe('Title from HTML')

          it 'does not update the document title if the response has a <title> tag inside an inline SVG image (bugfix)', asyncSpec (next) ->
            affix('.container').text('old container text')
            document.title = 'old document title'
            up.replace('.container', '/path', history: false, title: true)

            next =>
              @respondWith """
                <svg width="500" height="300" xmlns="http://www.w3.org/2000/svg">
                  <g>
                    <title>SVG Title Demo example</title>
                    <rect x="10" y="10" width="200" height="50" style="fill:none; stroke:blue; stroke-width:1px"/>
                  </g>
                </svg>

                <div class='container'>
                  new container text
                </div>
              """

            next =>
              expect($('.container')).toHaveText('new container text')
              expect(document.title).toBe('old document title')

          it "does not extract the title from the response or HTTP header if history isn't updated", asyncSpec (next) ->
            affix('.container').text('old container text')
            document.title = 'old document title'
            up.replace('.container', '/path', history: false)

            next =>
              @respondWith
                responseHeaders:
                  'X-Up-Title': 'Title from header'
                responseText: """
                <html>
                  <head>
                    <title>Title from HTML</title>
                  </head>
                  <body>
                    <div class='container'>
                      new container text
                    </div>
                  </body>
                </html>
              """

            next =>
              expect(document.title).toBe('old document title')

          it 'allows to pass an explicit title as { title } option', asyncSpec (next) ->
            affix('.container').text('old container text')
            up.replace('.container', '/path', title: 'Title from options')

            next =>
              @respondWith """
                <html>
                  <head>
                    <title>Title from HTML</title>
                  </head>
                  <body>
                    <div class='container'>
                      new container text
                    </div>
                  </body>
                </html>
              """

            next =>
              expect($('.container')).toHaveText('new container text')
              expect(document.title).toBe('Title from options')

        describe 'selector processing', ->

          it 'replaces multiple selectors separated with a comma', (done) ->
            promise = up.replace('.middle, .after', '/path')
            @respond()
            promise.then ->
              expect($('.before')).toHaveText('old-before')
              expect($('.middle')).toHaveText('new-middle')
              expect($('.after')).toHaveText('new-after')
              done()

          it 'replaces the body if asked to replace the "html" selector'

          it 'prepends instead of replacing when the target has a :before pseudo-selector', (done) ->
            promise = up.replace('.middle:before', '/path')
            @respond()
            promise.then ->
              expect($('.before')).toHaveText('old-before')
              expect($('.middle')).toHaveText('new-middleold-middle')
              expect($('.after')).toHaveText('old-after')
              done()

          it 'appends instead of replacing when the target has a :after pseudo-selector', (done) ->
            promise = up.replace('.middle:after', '/path')
            @respond()
            promise.then ->
              expect($('.before')).toHaveText('old-before')
              expect($('.middle')).toHaveText('old-middlenew-middle')
              expect($('.after')).toHaveText('old-after')
              done()

          it "lets the developer choose between replacing/prepending/appending for each selector", (done) ->
            promise = up.replace('.before:before, .middle, .after:after', '/path')
            @respond()
            promise.then ->
              expect($('.before')).toHaveText('new-beforeold-before')
              expect($('.middle')).toHaveText('new-middle')
              expect($('.after')).toHaveText('old-afternew-after')
              done()

          it 'understands non-standard CSS selector extensions such as :has(...)', (done) ->
            $first = affix('.boxx#first')
            $firstChild = $('<span class="first-child">old first</span>').appendTo($first)
            $second = affix('.boxx#second')
            $secondChild = $('<span class="second-child">old second</span>').appendTo($second)

            promise = up.replace('.boxx:has(.first-child)', '/path')
            @respondWith """
              <div class="boxx" id="first">
                <span class="first-child">new first</span>
              </div>
              """

            promise.then ->
              expect($('#first span')).toHaveText('new first')
              expect($('#second span')).toHaveText('old second')
              done()

          describe 'when selectors are missing on the page before the request was made', ->

            beforeEach ->
              up.dom.config.fallbacks = []

            it 'tries selectors from options.fallback before making a request', asyncSpec (next) ->
              affix('.box').text('old box')
              up.replace('.unknown', '/path', fallback: '.box')

              next => @respondWith '<div class="box">new box</div>'
              next => expect('.box').toHaveText('new box')

            it 'rejects the promise if all alternatives are exhausted', (done) ->
              promise = up.replace('.unknown', '/path', fallback: '.more-unknown')
              promise.catch (e) ->
                expect(e).toBeError(/Could not find target in current page/i)
                done()

            it 'considers a union selector to be missing if one of its selector-atoms are missing', asyncSpec (next) ->
              affix('.target').text('old target')
              affix('.fallback').text('old fallback')
              up.replace('.target, .unknown', '/path', fallback: '.fallback')

              next =>
                @respondWith """
                  <div class="target">new target</div>
                  <div class="fallback">new fallback</div>
                """

              next =>
                expect('.target').toHaveText('old target')
                expect('.fallback').toHaveText('new fallback')

            it 'tries a selector from up.dom.config.fallbacks if options.fallback is missing', asyncSpec (next) ->
              up.dom.config.fallbacks = ['.existing']
              affix('.existing').text('old existing')
              up.replace('.unknown', '/path')
              next => @respondWith '<div class="existing">new existing</div>'
              next => expect('.existing').toHaveText('new existing')

            it 'does not try a selector from up.dom.config.fallbacks and rejects the promise if options.fallback is false', (done) ->
              up.dom.config.fallbacks = ['.existing']
              affix('.existing').text('old existing')
              up.replace('.unknown', '/path', fallback: false).catch (e) ->
                expect(e).toBeError(/Could not find target in current page/i)
                done()

          describe 'when selectors are missing on the page after the request was made', ->

            beforeEach ->
              up.dom.config.fallbacks = []

            it 'tries selectors from options.fallback before swapping elements', asyncSpec (next) ->
              $target = affix('.target').text('old target')
              $fallback = affix('.fallback').text('old fallback')
              up.replace('.target', '/path', fallback: '.fallback')
              $target.remove()

              next =>
                @respondWith """
                  <div class="target">new target</div>
                  <div class="fallback">new fallback</div>
                """

              next =>
                expect('.fallback').toHaveText('new fallback')

            it 'rejects the promise if all alternatives are exhausted', (done) ->
              $target = affix('.target').text('old target')
              $fallback = affix('.fallback').text('old fallback')
              promise = up.replace('.target', '/path', fallback: '.fallback')
              $target.remove()
              $fallback.remove()

              u.nextFrame =>
                @respondWith """
                  <div class="target">new target</div>
                  <div class="fallback">new fallback</div>
                """

                u.nextFrame =>
                  promiseState promise, (state, value) ->
                    expect(state).toEqual('rejected')
                    expect(value).toBeError(/Could not find target in current page/i)
                    done()

            it 'considers a union selector to be missing if one of its selector-atoms are missing', asyncSpec (next) ->
              $target = affix('.target').text('old target')
              $target2 = affix('.target2').text('old target2')
              $fallback = affix('.fallback').text('old fallback')
              up.replace('.target, .target2', '/path', fallback: '.fallback')
              $target2.remove()

              next =>
                @respondWith """
                  <div class="target">new target</div>
                  <div class="target2">new target2</div>
                  <div class="fallback">new fallback</div>
                """
              next =>
                expect('.target').toHaveText('old target')
                expect('.fallback').toHaveText('new fallback')

            it 'tries a selector from up.dom.config.fallbacks if options.fallback is missing', asyncSpec (next) ->
              up.dom.config.fallbacks = ['.fallback']
              $target = affix('.target').text('old target')
              $fallback = affix('.fallback').text('old fallback')
              up.replace('.target', '/path')
              $target.remove()

              next =>
                @respondWith """
                  <div class="target">new target</div>
                  <div class="fallback">new fallback</div>
                """

              next =>
                expect('.fallback').toHaveText('new fallback')

            it 'does not try a selector from up.dom.config.fallbacks and rejects the promise if options.fallback is false', (done) ->
              up.dom.config.fallbacks = ['.fallback']
              $target = affix('.target').text('old target')
              $fallback = affix('.fallback').text('old fallback')
              promise = up.replace('.target', '/path', fallback: false)
              $target.remove()

              u.nextFrame =>
                @respondWith """
                  <div class="target">new target</div>
                  <div class="fallback">new fallback</div>
                """

                promise.catch (e) ->
                  expect(e).toBeError(/Could not find target in current page/i)
                  done()

          describe 'when selectors are missing in the response', ->

            beforeEach ->
              up.dom.config.fallbacks = []

            it 'tries selectors from options.fallback before swapping elements', asyncSpec (next) ->
              $target = affix('.target').text('old target')
              $fallback = affix('.fallback').text('old fallback')
              up.replace('.target', '/path', fallback: '.fallback')

              next =>
                @respondWith """
                  <div class="fallback">new fallback</div>
                """

              next =>
                expect('.target').toHaveText('old target')
                expect('.fallback').toHaveText('new fallback')

            it 'rejects the promise if all alternatives are exhausted', (done) ->
              $target = affix('.target').text('old target')
              $fallback = affix('.fallback').text('old fallback')
              promise = up.replace('.target', '/path', fallback: '.fallback')

              u.nextFrame =>
                @respondWith '<div class="unexpected">new unexpected</div>'

              promise.catch (e) ->
                expect(e).toBeError(/Could not find target in response/i)
                done()

            it 'considers a union selector to be missing if one of its selector-atoms are missing', asyncSpec (next) ->
              $target = affix('.target').text('old target')
              $target2 = affix('.target2').text('old target2')
              $fallback = affix('.fallback').text('old fallback')
              up.replace('.target, .target2', '/path', fallback: '.fallback')

              next =>
                @respondWith """
                  <div class="target">new target</div>
                  <div class="fallback">new fallback</div>
                """

              next =>
                expect('.target').toHaveText('old target')
                expect('.target2').toHaveText('old target2')
                expect('.fallback').toHaveText('new fallback')

            it 'tries a selector from up.dom.config.fallbacks if options.fallback is missing', asyncSpec (next) ->
              up.dom.config.fallbacks = ['.fallback']
              $target = affix('.target').text('old target')
              $fallback = affix('.fallback').text('old fallback')
              up.replace('.target', '/path')

              next =>
                @respondWith '<div class="fallback">new fallback</div>'

              next =>
                expect('.target').toHaveText('old target')
                expect('.fallback').toHaveText('new fallback')

            it 'does not try a selector from up.dom.config.fallbacks and rejects the promise if options.fallback is false', (done) ->
              up.dom.config.fallbacks = ['.fallback']
              $target = affix('.target').text('old target')
              $fallback = affix('.fallback').text('old fallback')
              promise = up.replace('.target', '/path', fallback: false)

              u.nextFrame =>
                @respondWith '<div class="fallback">new fallback</div>'

              promise.catch (e) ->
                expect(e).toBeError(/Could not find target in response/i)
                done()

        describe 'execution of script tags', ->

          beforeEach ->
            window.scriptTagExecuted = jasmine.createSpy('scriptTagExecuted')

          describe 'inline scripts', ->

            it 'executes only those script-tags in the response that get inserted into the DOM', (done) ->
              @responseText =
                """
                <div class="before">
                  new-before
                  <script type="text/javascript">
                    window.scriptTagExecuted('before')
                  </script>
                </div>
                <div class="middle">
                  new-middle
                  <script type="text/javascript">
                    window.scriptTagExecuted('middle')
                  </script>
                </div>
                """

              promise = up.replace('.middle', '/path')
              @respond()

              promise.then ->
                expect(window.scriptTagExecuted).not.toHaveBeenCalledWith('before')
                expect(window.scriptTagExecuted).toHaveBeenCalledWith('middle')
                done()

            it 'does not execute script-tags if up.dom.config.runInlineScripts is set to false', (done) ->
              up.dom.config.runInlineScripts = false

              @responseText = """
                <div class="middle">
                  new-middle
                  <script type="text/javascript">
                    window.scriptTagExecuted()
                  </script>
                </div>
                """

              promise = up.replace('.middle', '/path')
              @respond()

              promise.then ->
                expect(window.scriptTagExecuted).not.toHaveBeenCalled()
                done()

          describe 'linked scripts', ->

            beforeEach ->
              # Add a cache-buster to each path so the browser cache is guaranteed to be irrelevant
              @linkedScriptPath = "/assets/fixtures/linked_script.js?cache-buster=#{Math.random().toString()}"

            it 'does not execute linked scripts to prevent re-inclusion of javascript inserted before the closing body tag', (done) ->
              @responseText = """
                <div class="middle">
                  new-middle
                  <script type="text/javascript" src="#{@linkedScriptPath}">
                    alert("inside")
                  </script>
                </div>
                """

              promise = up.replace('.middle', '/path')
              @respond()

              promise.then =>

                # Must respond to this request, since jQuery makes them async: false
                if u.contains(@lastRequest().url, 'linked_script')
                  @respondWith('window.scriptTagExecuted()')

                # Now wait for jQuery to parse out <script> tags and fetch the linked scripts.
                # This actually happens with jasmine_ajax's fake XHR object.
                u.nextFrame =>
                  expect(jasmine.Ajax.requests.count()).toEqual(1)
                  expect(@lastRequest().url).not.toContain('linked_script')
                  expect(window.scriptTagExecuted).not.toHaveBeenCalled()
                  done()

            it 'does execute linked scripts if up.dom.config.runLinkedScripts is set to true', (done) ->
              up.dom.config.runLinkedScripts = true

              @responseText = """
                <div class="middle">
                  new-middle
                  <script type="text/javascript" src='#{@linkedScriptPath}'>
                  </script>
                </div>
                """

              promise = up.replace('.middle', '/path')
              @respond()

              promise.then =>

                # Must respond to this request, since jQuery makes them async: false
                if u.contains(@lastRequest().url, 'linked_script')
                  @respondWith('window.scriptTagExecuted()')

                # Now wait for jQuery to parse out <script> tags and fetch the linked scripts.
                # This actually happens with jasmine_ajax's fake XHR object.
                u.nextFrame =>
                  expect(jasmine.Ajax.requests.count()).toEqual(2)
                  expect(@lastRequest().url).toContain('linked_script')
                  done()


        describe 'with { restoreScroll: true } option', ->

          it 'restores the scroll positions of all viewports around the target', asyncSpec (next) ->

            $viewport = affix('div[up-viewport] .element').css
              'height': '100px'
              'width': '100px'
              'overflow-y': 'scroll'

            respond = =>
              @lastRequest().respondWith
                status: 200
                contentType: 'text/html'
                responseText: '<div class="element" style="height: 300px"></div>'

            up.replace('.element', '/foo')

            next => respond()
            next => $viewport.scrollTop(65)
            next => up.replace('.element', '/bar')
            next => respond()
            next => $viewport.scrollTop(0)
            next => up.replace('.element', '/foo', restoreScroll: true)
            # No need to respond because /foo has been cached before
            next => expect($viewport.scrollTop()).toEqual(65)


        describe 'with { reveal: true } option', ->

          beforeEach ->
            @revealedHTML = []
            @revealedText = []
            @revealOptions = {}

            @revealMock = up.layout.knife.mock('reveal').and.callFake ($element, options) =>
              @revealedHTML.push $element.get(0).outerHTML
              @revealedText.push $element.text().trim()
              @revealOptions = options
              u.resolvedDeferred()

          it 'reveals a new element before it is being replaced', asyncSpec (next) ->
            up.replace('.middle', '/path', reveal: true)

            next =>
              @respond()

            next =>
              expect(@revealMock).not.toHaveBeenCalledWith(@oldMiddle)
              expect(@revealedText).toEqual ['new-middle']

          describe 'when more than one fragment is replaced', ->

            it 'only reveals the first fragment', asyncSpec (next) ->
              up.replace('.middle, .after', '/path', reveal: true)

              next =>
                @respond()

              next =>
                expect(@revealMock).not.toHaveBeenCalledWith(@oldMiddle)
                expect(@revealedText).toEqual ['new-middle']

          describe 'when there is an anchor #hash in the URL', ->

            it 'scrolls to the top of a child with the ID of that #hash', asyncSpec (next) ->
              up.replace('.middle', '/path#three', reveal: true)
              @responseText =
                """
                <div class="middle">
                  <div id="one">one</div>
                  <div id="two">two</div>
                  <div id="three">three</div>
                </div>
                """

              next =>
                @respond()

              next =>
                expect(@revealedHTML).toEqual ['<div id="three">three</div>']
                expect(@revealOptions).toEqual { top: true }

            it "reveals the entire element if it has no child with the ID of that #hash", asyncSpec (next) ->
              up.replace('.middle', '/path#four', reveal: true)

              next =>
                @responseText =
                  """
                  <div class="middle">
                    new-middle
                  </div>
                  """
                @respond()

              next =>
                expect(@revealedText).toEqual ['new-middle']

          it 'reveals a new element that is being appended', (done) ->
            promise = up.replace('.middle:after', '/path', reveal: true)
            @respond()
            promise.then =>
              expect(@revealMock).not.toHaveBeenCalledWith(@oldMiddle)
              # Text nodes are wrapped in a .up-insertion container so we can
              # animate them and measure their position/size for scrolling.
              # This is not possible for container-less text nodes.
              expect(@revealedHTML).toEqual ['<div class="up-insertion">new-middle</div>']
              # Show that the wrapper is done after the insertion.
              expect($('.up-insertion')).not.toExist()
              done()

          it 'reveals a new element that is being prepended', (done) ->
            promise = up.replace('.middle:before', '/path', reveal: true)
            @respond()
            promise.then =>
              expect(@revealMock).not.toHaveBeenCalledWith(@oldMiddle)
              # Text nodes are wrapped in a .up-insertion container so we can
              # animate them and measure their position/size for scrolling.
              # This is not possible for container-less text nodes.
              expect(@revealedHTML).toEqual ['<div class="up-insertion">new-middle</div>']
              # Show that the wrapper is done after the insertion.
              expect($('.up-insertion')).not.toExist()
              done()

        it 'uses a { failTransition } option if the request failed'

      describeFallback 'canPushState', ->

        it 'makes a full page load', asyncSpec (next) ->
          spyOn(up.browser, 'loadPage')
          up.replace('.selector', '/path')

          next =>
            expect(up.browser.loadPage).toHaveBeenCalledWith('/path', jasmine.anything())

    describe 'up.extract', ->

      it 'Updates a selector on the current page with the same selector from the given HTML string', asyncSpec (next) ->

        affix('.before').text('old-before')
        affix('.middle').text('old-middle')
        affix('.after').text('old-after')

        html =
          """
          <div class="before">new-before</div>
          <div class="middle">new-middle</div>
          <div class="after">new-after</div>
          """

        up.extract('.middle', html)

        next ->
          expect($('.before')).toHaveText('old-before')
          expect($('.middle')).toHaveText('new-middle')
          expect($('.after')).toHaveText('old-after')

      it "throws an error if the selector can't be found on the current page", (done) ->
        html = '<div class="foo-bar">text</div>'
        promise = up.extract('.foo-bar', html)
        promiseState2(promise).then (result) =>
          expect(result.state).toEqual('rejected')
          expect(result.value).toMatch(/Could not find selector in current page, modal or popup/i)
          done()

      it "throws an error if the selector can't be found in the given HTML string", (done) ->
        affix('.foo-bar')
        promise = up.extract('.foo-bar', '')
        promiseState2(promise).then (result) =>
          expect(result.state).toEqual('rejected')
          expect(result.value).toMatch(/Could not find selector in response/i)
          done()

      it "ignores an element that matches the selector but also matches .up-destroying", (done) ->
        html = '<div class="foo-bar">text</div>'
        affix('.foo-bar.up-destroying')
        promise = up.extract('.foo-bar', html)
        promiseState2(promise).then (result) =>
          expect(result.state).toEqual('rejected')
          expect(result.value).toMatch(/Could not find selector/i)
          done()

      it "ignores an element that matches the selector but also matches .up-ghost", (done) ->
        html = '<div class="foo-bar">text</div>'
        affix('.foo-bar.up-ghost')
        promise = up.extract('.foo-bar', html)
        promiseState2(promise).then (result) =>
          expect(result.state).toEqual('rejected')
          expect(result.value).toMatch(/Could not find selector/i)
          done()

      it "ignores an element that matches the selector but also has a parent matching .up-destroying", (done) ->
        html = '<div class="foo-bar">text</div>'
        $parent = affix('.up-destroying')
        $child = affix('.foo-bar').appendTo($parent)
        promise = up.extract('.foo-bar', html)
        promiseState2(promise).then (result) =>
          expect(result.state).toEqual('rejected')
          expect(result.value).toMatch(/Could not find selector/i)
          done()

      it "ignores an element that matches the selector but also has a parent matching .up-ghost", (done) ->
        html = '<div class="foo-bar">text</div>'
        $parent = affix('.up-ghost')
        $child = affix('.foo-bar').appendTo($parent)
        promise = up.extract('.foo-bar', html)
        promiseState2(promise).then (result) =>
          expect(result.state).toEqual('rejected')
          expect(result.value).toMatch(/Could not find selector/i)
          done()

      it 'only replaces the first element matching the selector', asyncSpec (next) ->
        html = '<div class="foo-bar">text</div>'
        affix('.foo-bar')
        affix('.foo-bar')
        up.extract('.foo-bar', html)

        next =>
          elements = $('.foo-bar')
          expect($(elements.get(0)).text()).toEqual('text')
          expect($(elements.get(1)).text()).toEqual('')

      describe 'with { transition } option', ->

        it 'morphs between the old and new element', asyncSpec (next) ->
          affix('.element').text('version 1')
          up.extract('.element', '<div class="element">version 2</div>', transition: 'cross-fade', duration: 200)

          next =>
            @$ghost1 = $('.element.up-ghost:contains("version 1")')
            expect(@$ghost1).toHaveLength(1)
            expect(u.opacity(@$ghost1)).toBeAround(1.0, 0.1)

            @$ghost2 = $('.element.up-ghost:contains("version 2")')
            expect(@$ghost2).toHaveLength(1)
            expect(u.opacity(@$ghost2)).toBeAround(0.0, 0.1)

          next.after 190, =>
            expect(u.opacity(@$ghost1)).toBeAround(0.0, 0.3)
            expect(u.opacity(@$ghost2)).toBeAround(1.0, 0.3)

        it 'marks the old fragment and its ghost as .up-destroying during the transition', asyncSpec (next) ->
          affix('.element').text('version 1')
          up.extract('.element', '<div class="element">version 2</div>', transition: 'cross-fade', duration: 200)

          next =>
            $version1 = $('.element:not(.up-ghost):contains("version 1")')
            $version1Ghost = $('.element.up-ghost:contains("version 1")')
            expect($version1).toHaveLength(1)
            expect($version1Ghost).toHaveLength(1)
            expect($version1).toHaveClass('up-destroying')
            expect($version1Ghost).toHaveClass('up-destroying')

            $version2 = $('.element:not(.up-ghost):contains("version 2")')
            $version2Ghost = $('.element.up-ghost:contains("version 2")')
            expect($version2).toHaveLength(1)
            expect($version2Ghost).toHaveLength(1)
            expect($version2).not.toHaveClass('up-destroying')
            expect($version2Ghost).not.toHaveClass('up-destroying')

        it 'cancels an existing transition by instantly jumping to the last frame', asyncSpec (next) ->
          affix('.element').text('version 1')
          up.extract('.element', '<div class="element">version 2</div>', transition: 'cross-fade', duration: 200)

          next =>
            $ghost1 = $('.element.up-ghost:contains("version 1")')
            expect($ghost1).toHaveLength(1)
            expect($ghost1.css('opacity')).toBeAround(1.0, 0.1)

            $ghost2 = $('.element.up-ghost:contains("version 2")')
            expect($ghost2).toHaveLength(1)
            expect($ghost2.css('opacity')).toBeAround(0.0, 0.1)

          next =>
            up.extract('.element', '<div class="element">version 3</div>', transition: 'cross-fade', duration: 200)

          next =>
            $ghost1 = $('.element.up-ghost:contains("version 1")')
            expect($ghost1).toHaveLength(0)

            $ghost2 = $('.element.up-ghost:contains("version 2")')
            expect($ghost2).toHaveLength(1)
            expect($ghost2.css('opacity')).toBeAround(1.0, 0.1)

            $ghost3 = $('.element.up-ghost:contains("version 3")')
            expect($ghost3).toHaveLength(1)
            expect($ghost3.css('opacity')).toBeAround(0.0, 0.1)

        it 'delays the resolution of the returned promise until the transition is over', (done) ->
          affix('.element').text('version 1')
          resolution = jasmine.createSpy()
          promise = up.extract('.element', '<div class="element">version 2</div>', transition: 'cross-fade', duration: 30)
          promise.then(resolution)
          expect(resolution).not.toHaveBeenCalled()
          u.setTimer 80, ->
            expect(resolution).toHaveBeenCalled()
            done()

        describe 'when animation is disabled', ->

          beforeEach ->
            up.motion.config.enabled = false

          it 'immediately swaps the old and new elements without creating unnecessary ghosts', asyncSpec (next) ->
            affix('.element').text('version 1')
            up.extract('.element', '<div class="element">version 2</div>', transition: 'cross-fade', duration: 200)
            next =>
              expect($('.element')).toHaveText('version 2')
              expect($('.up-ghost')).toHaveLength(0)

      describe 'handling of [up-keep] elements', ->

        squish = (string) ->
          if u.isString(string)
            string = string.replace(/^\s+/g, '')
            string = string.replace(/\s+$/g, '')
            string = string.replace(/\s+/g, ' ')
          string

        beforeEach ->
# Need to refactor this spec file so examples don't all share one example
          $('.before, .middle, .after').remove()

        it 'keeps an [up-keep] element, but does replace other elements around it', asyncSpec (next) ->
          $container = affix('.container')
          $container.affix('.before').text('old-before')
          $container.affix('.middle[up-keep]').text('old-middle')
          $container.affix('.after').text('old-after')

          up.extract '.container', """
            <div class='container'>
              <div class='before'>new-before</div>
              <div class='middle' up-keep>new-middle</div>
              <div class='after'>new-after</div>
            </div>
            """

          next =>
            expect($('.before')).toHaveText('new-before')
            expect($('.middle')).toHaveText('old-middle')
            expect($('.after')).toHaveText('new-after')

        it 'keeps an [up-keep] element, but does replace text nodes around it', asyncSpec (next) ->
          $container = affix('.container')
          $container.html """
            old-before
            <div class='element' up-keep>old-inside</div>
            old-after
            """

          up.extract '.container', """
            <div class='container'>
              new-before
              <div class='element' up-keep>new-inside</div>
              new-after
            </div>
            """

          next =>
            expect(squish($('.container').text())).toEqual('new-before old-inside new-after')

        describe 'if an [up-keep] element is itself a direct replacement target', ->

          it "keeps that element", asyncSpec (next) ->
            affix('.keeper[up-keep]').text('old-inside')
            up.extract '.keeper', "<div class='keeper' up-keep>new-inside</div>"

            next =>
              expect($('.keeper')).toHaveText('old-inside')

          it "only emits an event up:fragment:kept, but not an event up:fragment:inserted", asyncSpec (next) ->
            insertedListener = jasmine.createSpy('subscriber to up:fragment:inserted')
            up.on('up:fragment:inserted', insertedListener)
            keptListener = jasmine.createSpy('subscriber to up:fragment:kept')
            up.on('up:fragment:kept', keptListener)
            up.on 'up:fragment:inserted', insertedListener
            $keeper = affix('.keeper[up-keep]').text('old-inside')
            up.extract '.keeper', "<div class='keeper' up-keep>new-inside</div>"

            next =>
              expect(insertedListener).not.toHaveBeenCalled()
              expect(keptListener).toHaveBeenCalledWith(jasmine.anything(), $('.keeper'), jasmine.anything())

        it "removes an [up-keep] element if no matching element is found in the response", asyncSpec (next) ->
          barCompiler = jasmine.createSpy()
          barDestructor = jasmine.createSpy()
          up.compiler '.bar', ($bar) ->
            text = $bar.text()
            barCompiler(text)
            return -> barDestructor(text)

          $container = affix('.container')
          $container.html """
            <div class='foo'>old-foo</div>
            <div class='bar' up-keep>old-bar</div>
            """
          up.hello($container)

          expect(barCompiler.calls.allArgs()).toEqual [['old-bar']]
          expect(barDestructor.calls.allArgs()).toEqual []

          up.extract '.container', """
            <div class='container'>
              <div class='foo'>new-foo</div>
            </div>
            """

          next =>
            expect($('.container .foo')).toExist()
            expect($('.container .bar')).not.toExist()

            expect(barCompiler.calls.allArgs()).toEqual [['old-bar']]
            expect(barDestructor.calls.allArgs()).toEqual [['old-bar']]

        it "updates an element if a matching element is found in the response, but that other element is no longer [up-keep]", asyncSpec (next) ->
          barCompiler = jasmine.createSpy()
          barDestructor = jasmine.createSpy()
          up.compiler '.bar', ($bar) ->
            text = $bar.text()
            console.info('Compiling %o', text)
            barCompiler(text)
            return -> barDestructor(text)

          $container = affix('.container')
          $container.html """
            <div class='foo'>old-foo</div>
            <div class='bar' up-keep>old-bar</div>
            """
          up.hello($container)

          expect(barCompiler.calls.allArgs()).toEqual [['old-bar']]
          expect(barDestructor.calls.allArgs()).toEqual []

          up.extract '.container', """
            <div class='container'>
              <div class='foo'>new-foo</div>
              <div class='bar'>new-bar</div>
            </div>
            """

          next =>
            expect($('.container .foo')).toHaveText('new-foo')
            expect($('.container .bar')).toHaveText('new-bar')

            expect(barCompiler.calls.allArgs()).toEqual [['old-bar'], ['new-bar']]
            expect(barDestructor.calls.allArgs()).toEqual [['old-bar']]

        it 'moves a kept element to the ancestry position of the matching element in the response', asyncSpec (next) ->
          $container = affix('.container')
          $container.html """
            <div class="parent1">
              <div class="keeper" up-keep>old-inside</div>
            </div>
            <div class="parent2">
            </div>
            """
          up.extract '.container', """
            <div class='container'>
              <div class="parent1">
              </div>
              <div class="parent2">
                <div class="keeper" up-keep>old-inside</div>
              </div>
            </div>
            """

          next =>
            expect($('.keeper')).toHaveText('old-inside')
            expect($('.keeper').parent()).toEqual($('.parent2'))

        it 'lets developers choose a selector to match against as the value of the up-keep attribute', asyncSpec (next) ->
          $container = affix('.container')
          $container.html """
            <div class="keeper" up-keep=".stayer"></div>
            """
          up.extract '.container', """
            <div class='container'>
              <div up-keep class="stayer"></div>
            </div>
            """

          next =>
            expect('.keeper').toExist()

        it 'does not compile a kept element a second time', asyncSpec (next) ->
          compiler = jasmine.createSpy('compiler')
          up.compiler('.keeper', compiler)
          $container = affix('.container')
          $container.html """
            <div class="keeper" up-keep>old-text</div>
            """

          up.hello($container)
          expect(compiler.calls.count()).toEqual(1)

          up.extract '.container', """
            <div class='container'>
              <div class="keeper" up-keep>new-text</div>
            </div>
            """

          next =>
            expect(compiler.calls.count()).toEqual(1)
            expect('.keeper').toExist()

        it 'does not lose jQuery event handlers on a kept element (bugfix)', asyncSpec (next) ->
          handler = jasmine.createSpy('event handler')
          up.compiler '.keeper', ($keeper) ->
            $keeper.on 'click', handler

          $container = affix('.container')
          $container.html """
            <div class="keeper" up-keep>old-text</div>
            """
          up.hello($container)

          up.extract '.container', """
            <div class='container'>
              <div class="keeper" up-keep>new-text</div>
            </div>
            """

          next =>
            expect('.keeper').toHaveText('old-text')

          next =>
            Trigger.click('.keeper')

          next =>
            expect(handler).toHaveBeenCalled()

        it 'lets listeners cancel the keeping by preventing default on an up:fragment:keep event', asyncSpec (next) ->
          $keeper = affix('.keeper[up-keep]').text('old-inside')
          $keeper.on 'up:fragment:keep', (event) -> event.preventDefault()
          up.extract '.keeper', "<div class='keeper' up-keep>new-inside</div>"
          next => expect($('.keeper')).toHaveText('new-inside')

        it 'lets listeners prevent up:fragment:keep event if the element was kept before (bugfix)', asyncSpec (next) ->
          $keeper = affix('.keeper[up-keep]').text('version 1')
          $keeper.on 'up:fragment:keep', (event) ->
            event.preventDefault() if event.$newElement.text() == 'version 3'

          next => up.extract '.keeper', "<div class='keeper' up-keep>version 2</div>"
          next => expect($('.keeper')).toHaveText('version 1')
          next => up.extract '.keeper', "<div class='keeper' up-keep>version 3</div>"
          next => expect($('.keeper')).toHaveText('version 3')

        it 'emits an up:fragment:kept event on a kept element and up:fragment:inserted on an updated parent', asyncSpec (next) ->
          insertedListener = jasmine.createSpy()
          up.on('up:fragment:inserted', insertedListener)
          keptListener = jasmine.createSpy()
          up.on('up:fragment:kept', keptListener)

          $container = affix('.container')
          $container.html """
            <div class="keeper" up-keep></div>
            """

          up.extract '.container', """
            <div class='container'>
              <div class="keeper" up-keep></div>
            </div>
            """

          next =>
            expect(insertedListener).toHaveBeenCalledWith(jasmine.anything(), $('.container'), jasmine.anything())
            expect(keptListener).toHaveBeenCalledWith(jasmine.anything(), $('.container .keeper'), jasmine.anything())

        it 'emits an up:fragment:kept event on a kept element with a newData property corresponding to the up-data attribute value of the discarded element', (next) ->
          keptListener = jasmine.createSpy()
          up.on 'up:fragment:kept', (event) -> keptListener(event.$element, event.newData)
          $container = affix('.container')
          $keeper = $container.affix('.keeper[up-keep]').text('old-inside')

          up.extract '.container', """
            <div class='container'>
              <div class='keeper' up-keep up-data='{ "foo": "bar" }'>new-inside</div>
            </div>
          """

          next =>
            expect($('.keeper')).toHaveText('old-inside')
            expect(keptListener).toHaveBeenCalledWith($keeper, { 'foo': 'bar' })

        it 'emits an up:fragment:kept with { newData: {} } if the discarded element had no up-data value', (next) ->
          keptListener = jasmine.createSpy()
          up.on('up:fragment:kept', keptListener)
          $container = affix('.container')
          $keeper = $container.affix('.keeper[up-keep]').text('old-inside')
          up.extract '.keeper', """
            <div class='container'>
              <div class='keeper' up-keep>new-inside</div>
            </div>
          """

          next =>
            expect($('.keeper')).toHaveText('old-inside')
            expect(keptListener).toEqual(jasmine.anything(), $('.keeper'), {})

        it 'reuses the same element and emits up:fragment:kept during multiple extractions', asyncSpec (next) ->
          keptListener = jasmine.createSpy()
          up.on 'up:fragment:kept', (event) -> keptListener(event.$element, event.newData)
          $container = affix('.container')
          $keeper = $container.affix('.keeper[up-keep]').text('old-inside')

          next =>
            up.extract '.keeper', """
              <div class='container'>
                <div class='keeper' up-keep up-data='{ \"key\": \"value1\" }'>new-inside</div>
              </div>
            """

          next =>
            up.extract '.keeper', """
              <div class='container'>
                <div class='keeper' up-keep up-data='{ \"key\": \"value2\" }'>new-inside</div>
            """

          next =>
            $keeper = $('.keeper')
            expect($keeper).toHaveText('old-inside')
            expect(keptListener).toHaveBeenCalledWith($keeper, { key: 'value1' })
            expect(keptListener).toHaveBeenCalledWith($keeper, { key: 'value2' })

        it "doesn't let the discarded element appear in a transition", (done) ->
          oldTextDuringTransition = undefined
          newTextDuringTransition = undefined
          transition = ($old, $new) ->
            oldTextDuringTransition = squish($old.text())
            newTextDuringTransition = squish($new.text())
            u.resolvedDeferred()
          $container = affix('.container')
          $container.html """
            <div class='foo'>old-foo</div>
            <div class='bar' up-keep>old-bar</div>
            """
          newHtml = """
            <div class='container'>
              <div class='foo'>new-foo</div>
              <div class='bar' up-keep>new-bar</div>
            </div>
            """
          promise = up.extract('.container', newHtml, transition: transition)
          promise.then ->
            expect(oldTextDuringTransition).toEqual('old-foo old-bar')
            expect(newTextDuringTransition).toEqual('new-foo old-bar')
            done()

    describe 'up.destroy', ->

      it 'removes the element with the given selector', (done) ->
        affix('.element')
        up.destroy('.element').then ->
          expect($('.element')).not.toExist()
          done()

      it 'calls destructors for custom elements', (done) ->
        up.compiler('.element', ($element) -> destructor)
        destructor = jasmine.createSpy('destructor')
        up.hello(affix('.element'))
        up.destroy('.element').then ->
          expect(destructor).toHaveBeenCalled()
          done()

      it 'allows to pass a new history entry as { history } option', (done) ->
        affix('.element')
        up.destroy('.element', history: '/new-path').then ->
          expect(location.href).toMatchUrl('/new-path')
          done()

      it 'allows to pass a new document title as { title } option', (done) ->
        affix('.element')
        up.destroy('.element', history: '/new-path', title: 'Title from options').then ->
          expect(document.title).toEqual('Title from options')
          done()


    describe 'up.reload', ->

      describeCapability 'canPushState', ->

        it 'reloads the given selector from the closest known source URL', asyncSpec (next) ->
          affix('.container[up-source="/source"] .element').find('.element').text('old text')

          next =>
            up.reload('.element')

          next =>
            expect(@lastRequest().url).toMatch(/\/source$/)
            @respondWith """
              <div class="container">
                <div class="element">new text</div>
              </div>
              """

          next =>
            expect($('.element')).toHaveText('new text')


      describeFallback 'canPushState', ->

        it 'makes a page load from the closest known source URL', asyncSpec (next) ->
          affix('.container[up-source="/source"] .element').find('.element').text('old text')
          spyOn(up.browser, 'loadPage')
          up.reload('.element')

          next =>
            expect(up.browser.loadPage).toHaveBeenCalledWith('/source', jasmine.anything())


    describe 'up.reset', ->

      it 'should have tests'

