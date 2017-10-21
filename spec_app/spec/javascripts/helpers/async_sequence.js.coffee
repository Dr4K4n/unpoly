u = up.util

LOG_ENABLED = true

window.asyncSpec = (args...) ->
  (done) ->

    plan = args.pop()
    options = args.pop() || {}

    queue = []

    insertCursor = 0

    log = (args...) ->
      if LOG_ENABLED
        args[0] = "[asyncSpec] #{args[0]}"
        up.log.debug(args...)

    insertAtCursor = (task) ->
      log('Inserting task at index %d: %o', insertCursor, task)
      # We insert at pointer instead of pushing to the end.
      # This way tasks can insert additional tasks at runtime.
      queue.splice(insertCursor, 0, task)
      insertCursor++

    next = (block) ->
      insertAtCursor [0, block, 'sync']

    next.next = next # alternative API

    next.after = (delay, block) ->
      insertAtCursor [delay, block, 'sync']

    next.await = (block) ->
      insertAtCursor  [0, block, 'async']

    # Call example body
    plan.call(this, next)

    runBlockSyncAndPoke = (block) ->
      try
        log('runBlockSync')
        block()
        pokeQueue()
      catch e
        done.fail(e)
        throw e

    runBlockAsyncThenPoke = (blockOrPromise) ->
      log('runBlockAsync')
      # On plan-level people will usually pass a function returning a promise.
      # During runtime people will usually pass a promise to delay the next step.
      promise = if u.isPromise(blockOrPromise) then blockOrPromise else blockOrPromise()
      promise.then => pokeQueue()
      promise.catch (e) => done.fail(e)

    pokeQueue = ->
      if entry = queue[runtimeCursor]
        log('Playing task at index %d', runtimeCursor)
        runtimeCursor++
        insertCursor++

        timing = entry[0]
        block = entry[1]
        callStyle = entry[2]

        log('Task is %s after %d ms: %o', callStyle, timing, block)

        switch timing
          when 'now'
            runBlockSyncAndPoke(block)
          else
            fun = ->
              # Move the block behind the microtask queue of that frame
              Promise.resolve().then ->
                if callStyle == 'sync'
                  runBlockSyncAndPoke(block)
                else # async
                  runBlockAsyncThenPoke(block)

            # Also move to the next frame
            setTimeout(fun, timing)
      else
        log('calling done()')
        done()

    runtimeCursor = insertCursor = 0
    pokeQueue()
