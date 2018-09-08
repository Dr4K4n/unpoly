#describe 'up.history', ->
#
#  u = up.util
#
#  beforeEach ->
#    up.history.config.enabled = true
#
#  describe 'JavaScript functions', ->
#
#    describe 'up.history.replace', ->
#
#      it 'should have tests'
#
#    describe 'up.history.url', ->
#
#      describeCapability 'canPushState', ->
#
#        it 'does not strip a trailing slash from the current URL', ->
#          history.replaceState?({}, 'title', '/host/path/')
#          expect(up.history.url()).toMatchUrl('/host/path/')
#
#    describe 'up.history.isUrl', ->
#
#      describeCapability 'canPushState', ->
#
#        it 'returns true if the given path is the current URL', ->
#          history.replaceState?({}, 'title', '/host/path/')
#          expect(up.history.isUrl('/host/path/')).toBe(true)
#
#        it 'returns false if the given path is not the current URL', ->
#          history.replaceState?({}, 'title', '/host/path/')
#          expect(up.history.isUrl('/host/other-path/')).toBe(false)
#
#        it 'returns true if the given full URL is the current URL', ->
#          history.replaceState?({}, 'title', '/host/path/')
#          expect(up.history.isUrl("http://#{location.host}/host/path/")).toBe(true)
#
#        it 'returns true if the given path is the current URL, but without a trailing slash', ->
#          history.replaceState?({}, 'title', '/host/path/')
#          expect(up.history.isUrl('/host/path')).toBe(true)
#
#        it 'returns true if the given path is the current URL, but with a trailing slash', ->
#          history.replaceState?({}, 'title', '/host/path')
#          expect(up.history.isUrl('/host/path/')).toBe(true)
#
#  describe 'unobtrusive behavior', ->
#
#    describe 'back button', ->
#
#      it 'calls destructor functions when destroying compiled elements (bugfix)', asyncSpec (next) ->
#        waitForBrowser = 70
#
#        # By default, up.history will replace the <body> tag when
#        # the user presses the back-button. We reconfigure this
#        # so we don't lose the Jasmine runner interface.
#        up.history.config.popTargets = ['.container']
#
#        constructorSpy = jasmine.createSpy('constructor')
#        destructorSpy = jasmine.createSpy('destructor')
#
#        up.compiler '.example', ($example) ->
#          constructorSpy()
#          return destructorSpy
#
#        up.history.push('/one')
#        up.history.push('/two')
#
#        $container = affix('.container')
#        $example = $container.affix('.example')
#        up.hello($example)
#
#        expect(constructorSpy).toHaveBeenCalled()
#
#        history.back()
#
#        next.after waitForBrowser, =>
#          expect(location.pathname).toEqual('/one')
#          @respondWith "<div class='container'>restored container text</div>"
#
#        next =>
#          expect(destructorSpy).toHaveBeenCalled()
#
#
#    describe '[up-back]', ->
#
#      describeCapability 'canPushState', ->
#
#        it 'sets an [up-href] attribute to the previous URL and sets the up-restore-scroll attribute to "true"', ->
#          up.history.push('/path1')
#          up.history.push('/path2')
#          $element = up.hello(affix('a[href="/path3"][up-back]').text('text'))
#          expect($element.attr('href')).toMatchUrl('/path3')
#          expect($element.attr('up-href')).toMatchUrl('/path1')
#          expect($element.attr('up-restore-scroll')).toBe('')
#          expect($element.attr('up-follow')).toBe('')
#
#      it 'does not overwrite an existing up-href or up-restore-scroll attribute'
#
#      it 'does not set an up-href attribute if there is no previous URL'
#
#      describeFallback 'canPushState', ->
#
#        it 'does not change the element', ->
#          $element = up.hello(affix('a[href="/three"][up-back]').text('text'))
#          expect($element.attr('up-href')).toBeUndefined()
#
#    describe 'scroll restoration', ->
#
#      describeCapability 'canPushState', ->
#
#        afterEach ->
#          $('.viewport').remove()
#
#        it 'restores the scroll position of viewports when the user hits the back button', asyncSpec (next) ->
#
#          longContentHtml = """
#            <div class="viewport" style="width: 100px; height: 100px; overflow-y: scroll">
#              <div class="content" style="height: 1000px"></div>
#            </div>
#          """
#
#          respond = => @respondWith(longContentHtml)
#
#          $viewport = $(longContentHtml).appendTo(document.body)
#
#          up.layout.config.viewports = ['.viewport']
#          up.history.config.popTargets = ['.viewport']
#
#          up.replace('.content', '/one')
#
#          next =>
#            respond()
#
#          next =>
#            $viewport.scrollTop(50)
#            up.replace('.content', '/two')
#
#          next =>
#            respond()
#
#          next =>
#            $('.viewport').scrollTop(150)
#            up.replace('.content', '/three')
#
#          next =>
#            respond()
#
#          next =>
#            $('.viewport').scrollTop(250)
#            history.back()
#
#          next.after 50, =>
#            respond() # we need to respond since we've never requested /two with the popTarget
#
#          next =>
#            expect($('.viewport').scrollTop()).toBe(150)
#            history.back()
#
#          next.after 50, =>
#            respond() # we need to respond since we've never requested /one with the popTarget
#
#          next =>
#            expect($('.viewport').scrollTop()).toBe(50)
#            history.forward()
#
#          next.after 50, =>
#            # No need to respond since we requested /two with the popTarget
#            # when we went backwards
#            expect($('.viewport').scrollTop()).toBe(150)
#            history.forward()
#
#          next.after 50, =>
#            respond() # we need to respond since we've never requested /three with the popTarget
#
#          next =>
#            expect($('.viewport').scrollTop()).toBe(250)
#
#        it 'restores the scroll position of two viewports marked with [up-viewport], but not configured in up.layout.config (bugfix)', asyncSpec (next) ->
#          up.history.config.popTargets = ['.container']
#
#          html = """
#            <div class="container">
#              <div class="viewport1" up-viewport style="width: 100px; height: 100px; overflow-y: scroll">
#                <div class="content1" style="height: 5000px">content1</div>
#              </div>
#              <div class="viewport2" up-viewport style="width: 100px; height: 100px; overflow-y: scroll">
#                <div class="content2" style="height: 5000px">content2</div>
#              </div>
#            </div>
#          """
#
#          respond = => @respondWith(html)
#
#          $screen = affix('.screen')
#          $screen.html(html)
#
#          up.replace('.content1, .content2', '/one', reveal: false)
#
#          next =>
#            respond()
#
#          next =>
#            $('.viewport1').scrollTop(3000)
#            $('.viewport2').scrollTop(3050)
#            expect('.viewport1').toBeScrolledTo(3000)
#            expect('.viewport2').toBeScrolledTo(3050)
#
#            up.replace('.content1, .content2', '/two', reveal: false)
#
#          next =>
#            respond()
#
#          next.after 50, =>
#            expect(location.href).toMatchUrl('/two')
#            history.back()
#
#          next.after 50, =>
#            # we need to respond since we've never requested the original URL with the popTarget
#            respond()
#
#          next =>
#            expect('.viewport1').toBeScrolledTo(3000)
#            expect('.viewport2').toBeScrolledTo(3050)
#
#
#    describe 'events', ->
#
#      describeCapability 'canPushState', ->
#
#        it 'emits up:history:* events as the user goes forwards and backwards through history', asyncSpec (next) ->
#          up.proxy.config.cacheSize = 0
#          up.history.config.popTargets = ['.viewport']
#
#          affix('.viewport .content')
#          respond = =>
#            @respondWith """
#              <div class="viewport">
#                <div class="content">content</div>
#              </div>
#              """
#
#          events = []
#          u.each ['up:history:pushed', 'up:history:restored'], (eventName) ->
#            up.on eventName, (event) ->
#              events.push [eventName, event.url]
#
#          normalize = up.history.normalizeUrl
#
#          up.replace('.content', '/foo')
#
#          next =>
#            respond()
#
#          next =>
#            expect(events).toEqual [
#              ['up:history:pushed', normalize('/foo')]
#            ]
#
#            up.replace('.content', '/bar')
#
#          next =>
#            respond()
#
#          next =>
#            expect(events).toEqual [
#              ['up:history:pushed', normalize('/foo')]
#              ['up:history:pushed', normalize('/bar')]
#            ]
#
#            up.replace('.content', '/baz')
#
#          next =>
#            respond()
#
#          next =>
#            expect(events).toEqual [
#              ['up:history:pushed', normalize('/foo')]
#              ['up:history:pushed', normalize('/bar')]
#              ['up:history:pushed', normalize('/baz')]
#            ]
#
#            history.back()
#
#          next.after 50, =>
#            respond()
#
#          next =>
#            expect(events).toEqual [
#              ['up:history:pushed', normalize('/foo')]
#              ['up:history:pushed', normalize('/bar')]
#              ['up:history:pushed', normalize('/baz')]
#              ['up:history:restored', normalize('/bar')]
#            ]
#
#            history.back()
#
#          next.after 50, =>
#            respond()
#
#          next =>
#            expect(events).toEqual [
#              ['up:history:pushed', normalize('/foo')]
#              ['up:history:pushed', normalize('/bar')]
#              ['up:history:pushed', normalize('/baz')]
#              ['up:history:restored', normalize('/bar')]
#              ['up:history:restored', normalize('/foo')]
#            ]
#
#            history.forward()
#
#          next.after 50, =>
#            respond()
#
#          next =>
#            expect(events).toEqual [
#              ['up:history:pushed', normalize('/foo')]
#              ['up:history:pushed', normalize('/bar')]
#              ['up:history:pushed', normalize('/baz')]
#              ['up:history:restored', normalize('/bar')]
#              ['up:history:restored', normalize('/foo')]
#              ['up:history:restored', normalize('/bar')]
#            ]
#
#            history.forward()
#
#          next.after 50, =>
#            respond() # we need to respond since we've never requested /baz with the popTarget
#
#          next =>
#            expect(events).toEqual [
#              ['up:history:pushed', normalize('/foo')]
#              ['up:history:pushed', normalize('/bar')]
#              ['up:history:pushed', normalize('/baz')]
#              ['up:history:restored', normalize('/bar')]
#              ['up:history:restored', normalize('/foo')]
#              ['up:history:restored', normalize('/bar')]
#              ['up:history:restored', normalize('/baz')]
#            ]
