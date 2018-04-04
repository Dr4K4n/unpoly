u = up.util

class up.ExtractCascade

  constructor: (selector, options) ->
    @options = u.options(options, humanizedTarget: 'selector', layer: 'auto')
    @options.transition = u.option(@options.transition, @options.animation)
    @options.hungry = u.option(@options.hungry, true)

    @candidates = @buildCandidates(selector)
    @plans = u.map @candidates, (candidate, i) =>
      planOptions = u.copy(@options)
      if i > 0
        # If we're using a fallback (any candidate that's not the first),
        # the original transition might no longer be appropriate.
        planOptions.transition = u.option(up.dom.config.fallbackTransition, @options.transition)
      new up.ExtractPlan(candidate, planOptions)

  buildCandidates: (selector) ->
    candidates = [selector, @options.fallback, up.dom.config.fallbacks]
    candidates = u.flatten(candidates)
    # Remove undefined, null and false from the list
    candidates = u.select(candidates, u.isTruthy)
    candidates = u.uniq(candidates)

    if @options.fallback == false || @options.provideTarget
      # Use the first defined candidate, but not `selector` since that
      # might be an undefined options.failTarget
      candidates = [candidates[0]]
    candidates

  oldPlan: =>
    @detectPlan('oldExists')

  newPlan: =>
    @detectPlan('newExists')

  matchingPlan: =>
    @detectPlan('matchExists')

  detectPlan: (checker) =>
    u.detect @plans, (plan) -> plan[checker]()

  bestPreflightSelector: =>
    if @options.provideTarget
      # We know that the target will be created right before swapping,
      # so just assume the first plan will work.
      plan = @plans[0]
    else
      plan = @oldPlan()

    if plan
      plan.compressedSelector()
    else
      @oldPlanNotFound()

  bestMatchingSteps: =>
    if plan = @matchingPlan()
      # Only when we have a match in the required selectors, we
      # append the optional steps for [up-hungry] elements.
      plan.addSteps(@hungrySteps())
      plan.compressedSteps()
    else
      @matchingPlanNotFound()

  hungrySteps: =>
    steps = []
    if @options.hungry
      $hungries = up.radio.hungrySelector().select()
      for hungry in $hungries
        $hungry = $(hungry)
        selector = u.selectorForElement($hungry)
        if $newHungry = @options.response.first(selector)
          transition = u.option(up.radio.config.hungryTransition, @options.transition)
          steps.push
            selector: selector
            $old: $hungry
            $new: $newHungry
            transition: transition
            reveal: false # we never auto-reveal a hungry element
            origin: null # don't let the hungry element auto-close a non-sticky modal or popup
    steps

  matchingPlanNotFound: =>
    # The job of this method is to simply throw an error.
    # However, we will investigate the reasons for the failure
    # so we can provide a more helpful error message.
    if @newPlan()
      @oldPlanNotFound()
    else
      if @oldPlan()
        message = "Could not find #{@options.humanizedTarget} in response"
      else
        message = "Could not match #{@options.humanizedTarget} in current page and response"
      if @options.inspectResponse
        inspectAction = { label: 'Open response', callback: @options.inspectResponse }
      up.fail(["#{message} (tried %o)", @candidates], action: inspectAction)

  oldPlanNotFound: =>
    layerProse = @options.layer
    layerProse = 'page, modal or popup' if layerProse == 'auto'
    up.fail("Could not find #{@options.humanizedTarget} in current #{layerProse} (tried %o)", @candidates)
