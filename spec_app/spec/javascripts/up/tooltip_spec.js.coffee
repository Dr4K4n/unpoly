describe 'up.tooltip', ->

  u = up.util

  describe 'JavaScript functions', ->
    
    describe 'up.tooltip.attach', ->
      
      it 'opens a tooltip with the given text', (done) ->
        $link = affix('span')
        up.tooltip.attach($link, html: 'tooltip text').then ->
          $tooltip = $('.up-tooltip')
          expect($tooltip).toHaveText('tooltip text')
          done()

      it 'allows HTML for the tooltip text when contents are given as { html } option', (done) ->
        $link = affix('span')
        up.tooltip.attach($link, html: '<b>text</b>').then ->
          $tooltip = $('.up-tooltip')
          expect($tooltip.html()).toEqual('<b>text</b>')
          done()

      it 'escapes HTML for the tooltip text when contents given as { text } option', (done) ->
        $link = affix('span')
        up.tooltip.attach($link, text: '<b>text</b>').then ->
          $tooltip = $('.up-tooltip')
          expect($tooltip.html()).toEqual('&lt;b&gt;text&lt;/b&gt;')
          done()

      describe 'positioning', ->

        beforeEach ->
          @$link = affix('span').text('button label')
          @$link.css(
            position: 'absolute'
            left: '200px'
            top: '200px'
            width: '50px'
            height: '50px'
          )

        beforeEach ->
          @restoreBodyHeight = u.temporaryCss('body', 'min-height': '3000px')

        afterEach ->
          @restoreBodyHeight()

        describe 'with { position: "top" }', ->

          it 'centers the tooltip above the given element', (done) ->
            @linkBox = @$link.get(0).getBoundingClientRect()
            up.tooltip.attach(@$link, html: 'tooltip text', position: 'top').then =>
              $tooltip = $('.up-tooltip')
              tooltipBox = $tooltip.get(0).getBoundingClientRect()
              expect(tooltipBox.top).toBeAround(@linkBox.top - tooltipBox.height, 15)
              expect(tooltipBox.left).toBeAround(@linkBox.left + 0.5 * (@linkBox.width - tooltipBox.width), 15)
              done()

        describe 'with { position: "right" }', ->

          it 'centers the tooltip at the right side of the given element', (done) ->
            @linkBox = @$link.get(0).getBoundingClientRect()
            up.tooltip.attach(@$link, html: 'tooltip text', position: 'right').then =>
              $tooltip = $('.up-tooltip')
              tooltipBox = $tooltip.get(0).getBoundingClientRect()
              expect(tooltipBox.top).toBeAround(@linkBox.top + 0.5 * (@linkBox.height - tooltipBox.height), 15)
              expect(tooltipBox.left).toBeAround(@linkBox.left + @linkBox.width, 15)
              done()

        describe 'with { position: "bottom" }', ->

          it 'centers the tooltip below the given element', (done) ->
            @linkBox = @$link.get(0).getBoundingClientRect()
            up.tooltip.attach(@$link, html: 'tooltip text', position: 'bottom').then =>
              $tooltip = $('.up-tooltip')
              tooltipBox = $tooltip.get(0).getBoundingClientRect()
              expect(tooltipBox.top).toBeAround(@linkBox.top + @linkBox.height, 15)
              expect(tooltipBox.left).toBeAround(@linkBox.left + 0.5 * (@linkBox.width - tooltipBox.width), 15)
              done()

        describe 'with { position: "left" }', ->

          it 'centers the tooltip at the left side of the given element', (done) ->
            @linkBox = @$link.get(0).getBoundingClientRect()
            up.tooltip.attach(@$link, html: 'tooltip text', position: 'left').then =>
              $tooltip = $('.up-tooltip')
              tooltipBox = $tooltip.get(0).getBoundingClientRect()
              expect(tooltipBox.top).toBeAround(@linkBox.top + 0.5 * (@linkBox.height - tooltipBox.height), 15)
              expect(tooltipBox.left).toBeAround(@linkBox.left - tooltipBox.width, 15)
              done()

        it 'gives the tooltip { position: "fixed" } if the given link is fixed', (done) ->
          # Let's test the harder case where the document is scrolled
          up.layout.scroll(document, 50)
          @$link.css(position: 'fixed')
          @linkBox = @$link.get(0).getBoundingClientRect()

          up.tooltip.attach(@$link, html: 'tooltip text', position: 'top').then =>
            $tooltip = $('.up-tooltip')
            tooltipBox = $tooltip.get(0).getBoundingClientRect()
            expect($tooltip.css('position')).toEqual('fixed')
            expect(tooltipBox.top).toBeAround(@linkBox.top - tooltipBox.height, 15)
            expect(tooltipBox.left).toBeAround(@linkBox.left + 0.5 * (@linkBox.width - tooltipBox.width), 15)
            done()

      it 'closes an existing tooltip'
      
      describe 'with position option', ->
        
        it 'anchors the tooltip at a different edge of the element'
      
    describe 'up.tooltip.close', ->

      it 'should have tests'
  
  describe 'unobtrusive behavior', ->
    
    describe '[up-tooltip]', ->

      it 'should have tests'

    describe '[up-tooltip-html]', ->

      it 'should have tests'

    describe 'when clicking on the body', ->

      beforeEach ->
        up.motion.config.enabled = false

      it 'closes the tooltip', asyncSpec (next) ->
        $link = affix('.link')
        up.tooltip.attach($link, text: 'Tooltip text')

        next =>
          expect(up.tooltip.isOpen()).toBe(true)
          Trigger.clickSequence($('body'))

        next =>
          expect(up.tooltip.isOpen()).toBe(false)

      it 'closes the tooltip when a an [up-instant] link removes its parent (and thus a click event never bubbles up to the document)', asyncSpec (next) ->
        $parent = affix('.parent')
        $parentReplacingLink = $parent.affix('a[href="/foo"][up-target=".parent"][up-instant]')
        $tooltipOpener = affix('.link')
        up.tooltip.attach($tooltipOpener, text: 'Tooltip text')

        next =>
          expect(up.tooltip.isOpen()).toBe(true)
          Trigger.clickSequence($parentReplacingLink)

        next =>
          expect(up.tooltip.isOpen()).toBe(false)

      it 'closes a tooltip when the user clicks on an [up-target] link outside the tooltip', asyncSpec (next) ->
        $target = affix('.target')
        $outsideLink = affix('a[href="/foo"][up-target=".target"]')
        $tooltipOpener = affix('.link')
        up.tooltip.attach($tooltipOpener, text: 'Tooltip text')

        next =>
          expect(up.tooltip.isOpen()).toBe(true)
          Trigger.clickSequence($outsideLink)

        next =>
          expect(up.tooltip.isOpen()).toBe(false)

      it 'closes a tooltip when the user clicks on an [up-instant] link outside the tooltip', asyncSpec (next) ->
        $target = affix('.target')
        $outsideLink = affix('a[href="/foo"][up-target=".target"][up-instant]')
        $tooltipOpener = affix('.link')
        up.tooltip.attach($tooltipOpener, text: 'Tooltip text')

        next =>
          expect(up.tooltip.isOpen()).toBe(true)
          Trigger.clickSequence($outsideLink)

        next =>
          expect(up.tooltip.isOpen()).toBe(false)
