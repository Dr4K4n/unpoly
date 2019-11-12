u = up.util
e = up.element
$ = jQuery

appendDefaultFallback = (parent) ->
  e.affix(parent, '.default-fallback')

#beforeAll ->
#  up.on 'click', 'a[href]', (event) ->
#    event.preventDefault()
#    console.error('Prevented default click behavior for link %o', event.target)
#  up.on 'submit', 'form', (event) ->
#    event.preventDefault()
#    console.error('Prevented default submit behavior for form %o', event.target)

beforeEach ->
  up.layer.config.all.targets = ['.default-fallback']
  up.fragment.config.targets = [] # no 'body'
  up.history.config.popTargets = ['.default-fallback']
  appendDefaultFallback(document.body)

  up.on 'up:layer:opening', (event) ->
    appendDefaultFallback(event.layer.element.querySelector(".up-#{event.layer.mode}-content"))

afterEach ->
  up.destroy('.default-fallback', log: false)
