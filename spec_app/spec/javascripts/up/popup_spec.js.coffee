describe 'up.popup', ->

  u = up.util

  describe 'JavaScript functions', ->

    describe 'up.popup.attach', ->

      beforeEach ->
        jasmine.addMatchers
          toSitBelow: (util, customEqualityTesters) ->
            compare: ($popup, $link) ->
              popupDims = $popup.get(0).getBoundingClientRect()
              linkDims = $link.get(0).getBoundingClientRect()
              pass:
                Math.abs(popupDims.right - linkDims.right) < 1.0 && Math.abs(popupDims.top - linkDims.bottom) < 1.0

      beforeEach ->
        @restoreBodyHeight = u.temporaryCss('body', 'min-height': '3000px')

      afterEach ->
        @restoreBodyHeight()

      it "loads this link's destination in a popup positioned under the given link", asyncSpec (next) ->
        $container = affix('.container')
        $container.css
          position: 'absolute'
          left: '100px'
          top: '50px'

        $link = $container.affix('a[href="/path/to"][up-popup=".middle"]').text('link')

        up.popup.attach($link)

        next =>
          expect(@lastRequest().url).toMatch /\/path\/to$/
          @respondWith """
            <div class="before">new-before</div>
            <div class="middle">new-middle</div>
            <div class="after">new-after</div>
            """

        next =>
          $popup = $('.up-popup')
          expect($popup).toExist()
          expect($popup.find('.middle')).toHaveText('new-middle')
          expect($popup.find('.before')).not.toExist()
          expect($popup.find('.after')).not.toExist()
          expect($popup.css('position')).toEqual('absolute')
          expect($popup).toSitBelow($link)

      it 'gives the popup { position: "fixed" } if the given link is fixed', asyncSpec (next) ->
        # Let's test the harder case where the document is scrolled
        up.layout.scroll(document, 50)
        $container = affix('.container')
        $container.css
          position: 'fixed'
          left: '100px'
          top: '50px'
        $link = $container.affix('a[href="/path/to"][up-popup=".content"]').text('link')

        up.popup.attach($link)

        next =>
          @respondWith('<div class="content">popup-content</div>')

        next =>
          $popup = $('.up-popup')
          expect($popup.css('position')).toEqual('fixed')
          expect($popup).toSitBelow($link)

      it 'never resolves the open() promise and shows no error if close() was called before the response was received', asyncSpec (next) ->
        $span = affix('span')
        openPromise = up.popup.attach($span, url: '/foo', target: '.container')

        next =>
          up.popup.close()

        next =>
          respond = => @respondWith('<div class="container">text</div>')
          expect(respond).not.toThrowError()

        next.await =>
          expect($('.up-toast')).not.toExist()
          promise = promiseState2(openPromise)
          promise.then (state) => expect(state).toEqual('pending')

      describe 'with { html } option', ->

        it 'extracts the selector from the given HTML string', asyncSpec (next) ->
          $span = affix('span')
          next.await up.popup.attach($span, target: '.container', html: "<div class='container'>container contents</div>")
          next => expect($('.up-popup')).toHaveText('container contents')

      describe 'opening a popup while another modal is open', ->

        it 'closes the current popup and wait for its close animation to finish before starting the open animation of a second popup', asyncSpec (next) ->
          $span = affix('span')
          up.popup.config.openAnimation = 'fade-in'
          up.popup.config.openDuration = 5
          up.popup.config.closeAnimation = 'fade-out'
          up.popup.config.closeDuration = 60

          events = []
          u.each ['up:popup:open', 'up:popup:opened', 'up:popup:close', 'up:popup:closed'], (event) ->
            up.on event, -> events.push(event)

          up.popup.attach($span, { target: '.target', html: '<div class="target">response1</div>' })

          next =>
            # First popup is starting opening animation
            expect(events).toEqual ['up:popup:open']
            expect($('.target')).toHaveText('response1')

          next.after 80, ->
            # First popup has completed opening animation
            expect(events).toEqual ['up:popup:open', 'up:popup:opened']
            expect($('.target')).toHaveText('response1')

            # We open another popup, which will cause the first modal to start closing
            up.popup.attach($span, { target: '.target', html: '<div class="target">response2</div>' })

          next.after 20, ->
            # Second popup is still waiting for first popup's closing animation to finish.
            expect(events).toEqual ['up:popup:open', 'up:popup:opened', 'up:popup:close']
            expect($('.target')).toHaveText('response1')

          next.after 200, ->
            # First popup has finished closing, second popup has finished opening.
            expect(events).toEqual ['up:popup:open', 'up:popup:opened', 'up:popup:close', 'up:popup:closed', 'up:popup:open', 'up:popup:opened']
            expect($('.target')).toHaveText('response2')

    describe 'up.popup.coveredUrl', ->

      describeCapability 'canPushState', ->

        it 'returns the URL behind the popup', asyncSpec (next) ->
          up.history.replace('/foo')
          expect(up.popup.coveredUrl()).toBeMissing()

          $popupLink = affix('a[href="/bar"][up-popup=".container"][up-history="true"]')
          Trigger.clickSequence($popupLink)

          next =>
            @respondWith('<div class="container">text</div>')
            expect(up.popup.coveredUrl()).toEqualUrl('/foo')

            next.await up.popup.close()

          next =>
            expect(up.popup.coveredUrl()).toBeMissing()

    describe 'up.popup.close', ->

      it 'should have tests'

    describe 'up.popup.source', ->

      it 'should have tests'

  describe 'unobtrusive behavior', ->

    describe 'a[up-popup]', ->

      beforeEach ->
        @stubAttach = =>
          @$link = affix('a[href="/path"][up-popup=".target"]')
          @attachSpy = up.popup.knife.mock('attachAsap').and.returnValue(u.resolvedPromise())
          @defaultSpy = up.link.knife.mock('allowDefault').and.callFake((event) -> event.preventDefault())

      it 'opens the clicked link in a popup', ->
        @stubAttach()
        Trigger.click(@$link)
        expect(@attachSpy).toHaveBeenCalledWith(@$link)

      # IE does not call JavaScript and always performs the default action on right clicks
      unless navigator.userAgent.match(/Trident/)
        it 'does nothing if the right mouse button is used', ->
          @stubAttach()
          Trigger.click(@$link, button: 2)
          expect(@attachSpy).not.toHaveBeenCalled()

      it 'does nothing if shift is pressed during the click', ->
        @stubAttach()
        Trigger.click(@$link, shiftKey: true)
        expect(@attachSpy).not.toHaveBeenCalled()

      it 'does nothing if ctrl is pressed during the click', ->
        @stubAttach()
        Trigger.click(@$link, ctrlKey: true)
        expect(@attachSpy).not.toHaveBeenCalled()

      it 'does nothing if meta is pressed during the click', ->
        @stubAttach()
        Trigger.click(@$link, metaKey: true)
        expect(@attachSpy).not.toHaveBeenCalled()

      it 'closes an existing popup before opening the new popup', asyncSpec (next) ->

        up.popup.config.openDuration = 0
        up.popup.config.closeDuration = 0

        $link1 = affix('a[href="/path1"][up-popup=".target"]')
        $link2 = affix('a[href="/path2"][up-popup=".target"]')

        events = []
        u.each ['up:popup:open', 'up:popup:opened', 'up:popup:close', 'up:popup:closed'], (event) ->
          up.on event, -> events.push(event)

        Trigger.click($link1)

        next =>
          expect(events).toEqual ['up:popup:open']
          @respondWith('<div class="target">text1</div>')

        next =>
          expect(events).toEqual ['up:popup:open', 'up:popup:opened']
          Trigger.click($link2)

        next =>
          expect(events).toEqual ['up:popup:open', 'up:popup:opened', 'up:popup:close', 'up:popup:closed', 'up:popup:open']
          @respondWith('<div class="target">text1</div>')

        next =>
          expect(events).toEqual ['up:popup:open', 'up:popup:opened', 'up:popup:close', 'up:popup:closed', 'up:popup:open', 'up:popup:opened']


      describe 'with [up-instant] modifier', ->

        beforeEach ->
          @stubAttach()
          @$link.attr('up-instant', '')

        it 'opens the modal on mousedown (instead of on click)', ->
          Trigger.mousedown(@$link)
          expect(@attachSpy.calls.mostRecent().args[0]).toEqual(@$link)

        it 'does nothing on mouseup', ->
          Trigger.mouseup(@$link)
          expect(@attachSpy).not.toHaveBeenCalled()

        it 'does nothing on click', ->
          Trigger.click(@$link)
          expect(@attachSpy).not.toHaveBeenCalled()

        # IE does not call JavaScript and always performs the default action on right clicks
        unless navigator.userAgent.match(/Trident/)
          it 'does nothing if the right mouse button is pressed down', ->
            Trigger.mousedown(@$link, button: 2)
            expect(@attachSpy).not.toHaveBeenCalled()

        it 'does nothing if shift is pressed during mousedown', ->
          Trigger.mousedown(@$link, shiftKey: true)
          expect(@attachSpy).not.toHaveBeenCalled()

        it 'does nothing if ctrl is pressed during mousedown', ->
          Trigger.mousedown(@$link, ctrlKey: true)
          expect(@attachSpy).not.toHaveBeenCalled()

        it 'does nothing if meta is pressed during mousedown', ->
          Trigger.mousedown(@$link, metaKey: true)
          expect(@attachSpy).not.toHaveBeenCalled()

      describe 'with [up-method] modifier', ->

        it 'honours the given method', asyncSpec (next) ->
          $link = affix('a[href="/path"][up-popup=".target"][up-method="post"]')
          Trigger.click($link)

          next =>
            expect(@lastRequest().method).toEqual 'POST'

    describe '[up-close]', ->

      backgroundClicked = undefined

      beforeEach ->
        up.motion.config.enabled = false
        backgroundClicked = jasmine.createSpy('background clicked')
        up.on 'click', backgroundClicked

      describe 'when clicked inside a popup', ->

        it 'closes the open popup and halts the event chain', asyncSpec (next) ->
          $opener = affix('a')
          up.popup.attach($opener, html: '<div class="target">text</div>', target: '.target')

          next =>
            $popup = affix('.up-popup')
            $closer = $popup.affix('a[up-close]') # link is within the popup
            up.hello($closer)
            Trigger.clickSequence($closer)

          next =>
            expect(up.popup.isOpen()).toBe(false)
            expect(backgroundClicked).not.toHaveBeenCalled()

      describe 'when clicked inside a popup when a modal is open', ->

        it 'closes the popup, but not the modal', asyncSpec (next) ->
          up.modal.extract '.modalee', '<div class="modalee"></div>'

          next =>
            $modalee = $('.up-modal .modalee')
            $opener = $modalee.affix('a')
            up.popup.attach($opener, html: '<div class="popupee">text</div>', target: '.popupee')

          next =>
            $popupee = $('.up-popup .popupee')
            $closer = $popupee.affix('a[up-close]') # link is within the popup
            up.hello($closer)
            Trigger.clickSequence($closer)

          next =>
            expect(up.popup.isOpen()).toBe(false)
            expect(up.modal.isOpen()).toBe(true)
            expect(backgroundClicked).not.toHaveBeenCalled()

      describe 'when no popup is open', ->

        it 'does nothing and allows the event chain to continue', asyncSpec (next) ->
          $link = affix('a[up-close]') # link is outside the popup
          up.hello($link)
          Trigger.clickSequence($link)

          next =>
            expect(up.popup.isOpen()).toBe(false)
            expect(backgroundClicked).toHaveBeenCalled()

    describe 'when replacing content', ->

      beforeEach ->
        up.motion.config.enabled = false

      it 'prefers to replace a selector within the popup', asyncSpec (next) ->
        $outside = affix('.foo').text('old outside')
        $link = affix('.link')
        up.popup.attach($link, target: '.foo', html: "<div class='foo'>old inside</div>")

        next =>
          up.extract('.foo', "<div class='foo'>new text</div>")

        next =>
          expect($outside).toBeInDOM()
          expect($outside).toHaveText('old outside')
          expect($('.up-popup')).toHaveText('new text')

      it 'auto-closes the popup when a replacement from inside the popup affects a selector behind the popup', asyncSpec (next) ->
        affix('.outside').text('old outside')
        $link = affix('.link')
        up.popup.attach($link, target: '.inside', html: "<div class='inside'>old inside</div>")

        next =>
          up.extract('.outside', "<div class='outside'>new outside</div>", origin: $('.inside'))

        next =>
          expect($('.outside')).toHaveText('new outside')
          expect($('.up-popup')).not.toExist()

      it 'does not restore the covered URL when auto-closing', asyncSpec (next) ->
        up.motion.config.enabled = true
        up.popup.config.openDuration = 0
        up.popup.config.closeDuration = 20
        up.popup.config.history = true

        affix('.outside').text('old outside')
        $link = affix('.link')
        up.popup.attach($link, url: '/path', target: '.inside')

        next =>
          @respondWith("<div class='inside'>old inside</div>")

        next =>
          up.extract('.outside', "<div class='outside'>new outside</div>",
            origin: $('.inside'), history: '/new-location') # Provoke auto-close

        next =>
          expect(location.href).toEqualUrl '/new-location'

      it 'does not auto-close the popup when a replacement from inside the popup affects a selector inside the popup', asyncSpec (next) ->
        affix('.outside').text('old outside')
        $link = affix('.link')
        up.popup.attach($link, target: '.inside')

        next =>
          @respondWith("<div class='inside'>old inside</div>")

        next =>
          up.extract('.inside', "<div class='inside'>new inside</div>", origin: $('.inside'))

        next =>
          expect($('.inside')).toHaveText('new inside')
          expect($('.up-popup')).toExist()

      it 'does not auto-close the popup when a replacement from outside the popup affects a selector outside the popup', asyncSpec (next) ->
        affix('.outside').text('old outside')
        $link = affix('.link')
        up.popup.attach($link, target: '.inside', html: "<div class='inside'>old inside</div>")

        next =>
          up.extract('.outside', "<div class='outside'>new outside</div>", origin: $('.outside'))

        next =>
          expect($('.outside')).toHaveText('new outside')
          expect($('.up-popup')).toExist()

      it 'does not auto-close the popup when a replacement from outside the popup affects a selector inside the popup', asyncSpec (next) ->
        affix('.outside').text('old outside')
        $link = affix('.link')
        up.popup.attach($link, target: '.inside', html: "<div class='inside'>old inside</div>")

        next =>
          up.extract('.inside', "<div class='inside'>new inside</div>", origin: $('.outside'))

        next =>
          expect($('.inside')).toHaveText('new inside')
          expect($('.up-popup')).toExist()

    describe 'when clicking on the body', ->

      beforeEach ->
        up.motion.config.enabled = false

      it 'closes the popup', asyncSpec (next) ->
        affix('.outside').text('old outside')
        $link = affix('.link')
        up.popup.attach($link, target: '.inside', html: "<div class='inside'>inside</div>")

        next =>
          expect(up.popup.isOpen()).toBe(true)
          Trigger.clickSequence($('body'))

        next =>
          expect(up.popup.isOpen()).toBe(false)

      it 'closes the popup when a an [up-instant] link removes its parent (and thus a click event never bubbles up to the document)', asyncSpec (next) ->
        $parent = affix('.parent')
        $parentReplacingLink = $parent.affix('a[href="/foo"][up-target=".parent"][up-instant]')
        $popupOpener = affix('.link')
        up.popup.attach($popupOpener, target: '.inside', html: "<div class='inside'>inside</div>")

        next =>
          expect(up.popup.isOpen()).toBe(true)
          Trigger.clickSequence($parentReplacingLink)

        next =>
          expect(up.popup.isOpen()).toBe(false)

      it 'closes the popup when the user clicks on an [up-target] link outside the popup', asyncSpec (next) ->
        $target = affix('.target')
        $outsideLink = affix('a[href="/foo"][up-target=".target"]')
        $popupOpener = affix('.link')
        up.popup.attach($popupOpener, target: '.inside', html: "<div class='inside'>inside</div>")

        next =>
          expect(up.popup.isOpen()).toBe(true)
          Trigger.clickSequence($outsideLink)

        next =>
          expect(up.popup.isOpen()).toBe(false)

      it 'closes the popup when the user clicks on an [up-instant] link outside the popup', asyncSpec (next) ->
        $target = affix('.target')
        $outsideLink = affix('a[href="/foo"][up-target=".target"][up-instant]')
        $popupOpener = affix('.link')
        up.popup.attach($popupOpener, target: '.inside', html: "<div class='inside'>inside</div>")

        next =>
          expect(up.popup.isOpen()).toBe(true)
          Trigger.clickSequence($outsideLink)

        next =>
          expect(up.popup.isOpen()).toBe(false)

      it 'does not close the popup if a link outside the popup is followed with the up.follow function (bugfix)', asyncSpec (next) ->
        $target = affix('.target')
        $outsideLink = affix('a[href="/foo"][up-target=".target"]')
        $popupOpener = affix('.link')
        up.popup.attach($popupOpener, target: '.inside', html: "<div class='inside'>inside</div>")

        next =>
          expect(up.popup.isOpen()).toBe(true)
          up.follow($outsideLink)

        next =>
          expect(up.popup.isOpen()).toBe(true)

      it 'does not close the popup if a form outside the popup is followed with the up.submit function (bugfix)', asyncSpec (next) ->
        $target = affix('.target')
        $outsideForm = affix('form[action="/foo"][up-target=".target"]')
        $popupOpener = affix('.link')
        up.popup.attach($popupOpener, target: '.inside', html: "<div class='inside'>inside</div>")

        next =>
          expect(up.popup.isOpen()).toBe(true)
          up.submit($outsideForm)

        next =>
          expect(up.popup.isOpen()).toBe(true)
