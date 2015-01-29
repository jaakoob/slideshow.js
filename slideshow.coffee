# out: slideshow.js
'use strict'
# requestAnimationFrame polyfill
# http://paulirish.com/2011/requestanimationframe-for-smart-animating/
# http://my.opera.com/emoller/blog/2011/12/20/requestanimationframe-for-smart-er-animating

# requestAnimationFrame polyfill by Erik Möller. fixes from Paul Irish and Tino Zijdel

# MIT license

do (root = window ? this) ->
  lastTime = 0
  vendors = ['ms', 'moz', 'webkit', 'o']
  i = 0
  while i < vendors.length and not root.requestAnimationFrame
    vendor = vendors[i++]
    root.requestAnimationFrame = root["#{vendor}RequestAnimationFrame"]
    root.cancelAnimationFrame = root["#{vendor}CancelAnimationFrame"] ? root["#{vendor}CancelRequestAnimationFrame"]


  unless root.requestAnimationFrame?
    root.requestAnimationFrame = (callback) ->
      currTime = new Date().getTime()
      timeToCall = Math.max 0, 16 - (currTime - lastTime)
      id = root.setTimeout (-> callback currTime + timeToCall), timeToCall
      lastTime = currTime + timeToCall
      id

  unless root.cancelAnimationFrame?
    root.cancelAnimationFrame = (id) ->
      clearTimeout id

# end requestAnimationFrame polyfill

# functions stolen from underscore and translated to coffee-script
# Underscore.js 1.7.0
# http://underscorejs.org
# (c) 2009-2014 Jeremy Ashkenas, DocumentCloud and Investigative Reporters & Editors
# Underscore may be freely distributed under the MIT license.

isNaN = isNaN ? (obj) -> isNumber obj and obj isnt +obj

isNumber = (obj) -> Object::toString.call(obj) is '[object Number]'

isObject = (obj) -> (type = typeof obj) is 'object' or type is 'function'

extend = (target, objects...) ->
  return unless isObject target
  for object in objects
    for own prop of object
      target[prop] = object[prop]
  target

indexOf = (array, match) ->
  return unless array?
  return i for item, i in array when item is match
  -1

# end functions stolen from underscore

# bind(fn, context) binds context to fn

bind = (fn, context) -> -> fn.apply context, [].slice.call arguments

# end bind

# vendorPrefix returns vendor prefixed css property (e.g. prefix('transform') -> 'webkitTransform')

prefix = do (root = window ? this) ->
  prefixes = {}

  (prop) ->
    return prefixes[prop] if prop of prefixes
    style = root.document.createElement('div').style
    return prefixes[prop] = prop if prop of style
    prop = prop.charAt(0).toUpperCase() + prop[1..]
    for vendor in ['moz', 'webkit', 'khtml', 'o', 'ms']
      prefixed = "#{vendor}#{prop}"
      return prefixes[prop] = prefixed if prefixed of style
    prefixes[prop] = false

# end vendorPrefix

factory = (document) ->
  class Slideshow
    constructor: (element, opts) ->
      # test if element is a valid html element or maybe
      # a jQuery object or Backbone View
      unless element.nodeType is 1
        if element[0]? then element = element[0] #jQuery
        if element.el? then element = element.el #Backbone
      if element.nodeType isnt 1 then throw new Error 'No valid element provided'
      @opts = extend {}, defaults, opts
      @el = element
      # and go!
      init.call @

    # private methods and variables

    defaults =
      touchEnabled: true # enable touch events
      preventScroll: true # call event.preventDefault in the touch events
      animationDuration: 400 # duration of the animation
      conditions: [ # conditions array, see README.md
        distance: .1
        time: 250
        durationMod: .5
      ,
        distance: .3
        time: 500
      ,
        distance: .5
      ]
      effect: # effect object, see README.md
        before: (slideState, slideElement) ->
          slideElement.style.display = 'block'
          ###
          slideState  is either -1, 0 or 1
          if slideState === 0 then this is the current slide and we want to show it, so set translateX(0)
          if slideState === -1 then this is the previous slide (to the left) so translateX(-100%)
          if slideState === 1 then this is the next slide (to the right) so translateX(100%)
          ###
          transform = prefix 'transform'
          X = -slideState * 100
          if transform
            slideElement.style[transform] = "translateX(#{X}%)"
          else
            slideElement.style.left = "#{X}%"
        progress: (slideState, progress, slideElement) ->
          ###
          slideState = either 0 or 1
          0 <= Math.abs(progress) <= 1, but progress can also be negative.
          progress < 0 indicates movement to the left
          progress > 0 indicates movement to the right

          if slideState === 0 then this is the current slide and we want it to move away as progress increases:
          X1 = 100 * p where p = progress
          if slideState === 1 then this is the target slide and we want it to move in from the left/right as progress increases:
          X2 = 100 * (-p / |p|) * (|p| - 1) where |p| = Math.abs(progress)

          X = (1 - S) * X1 + S * X2 where S = slideState
          X is the translateX value that should be set on this slide

          X = (1 - S) * 100 * p + S * 100 * (-p / |p|) * (1 - |p|)
          X = 100 * p * ( (1 - S) - S * (1 / |p|) * (1 - |p|) )
          X = 100 * p * ( 1 - S - S * ( (1 / |p|) - 1 ) )
          X = 100 * p * ( 1 - S + S * (1 - (1 / |p|) ) )
          X = 100 * p * ( 1 - S + S - (S / |p|) )
          X = 100 * p * ( 1 - (S / |p|) )
          ###
          transform = prefix 'transform'
          X = 100 * progress * (1 - slideState / Math.abs progress)
          if transform
            slideElement.style[transform] = "translateX(#{X}%)"
          else
            slideElement.style.left = "#{X}%"
        after: (slideState, slideElement) ->
          ###
          slideState is either 0 or 1
          if slideState === 0 then this is the previously visible slide and it must be hidden
          if slideState === 1 then this is the currently visible slide and it must be visible
          ###
          slideElement.style.display = if slideState > 0 then 'block' else 'none'

    init = ->
      initSlides.call @
      initTouchEvents.call @

    initSlides = ->
      # we don't want the slides to be visible outside their container
      @el.style.overflow = 'hidden'
      beforeFn = @opts.effect.before
      afterFn = @opts.effect.after
      # el.children may behave weird in IE8
      @slides = @el.children ? @el.childNodes
      @current = 0
      for slide, i in @slides when i isnt @current
        # call the before and after functions once on all but the first
        # slide, so all slides
        # are positioned properly
        beforeFn?.call @, 1, slide
        afterFn?.call @, 0, slide
      # call the before on the first slide to properly position it
      beforeFn?.call @, 0, @slides[@current]
      afterFn?.call @, 1, @slides[@current]

    initTouchEvents = ->
      # return unless TouchEvent is supported and it is not explicitly disabled
      return unless @touchEnabled = @opts.touchEnabled and TouchEvent?
      @el.addEventListener 'touchstart', (e) => touchstart.call @, e
      @el.addEventListener 'touchmove', (e) => touchmove.call @, e
      @el.addEventListener 'touchend', (e) => touchend.call @, e

    setCurrentSlide = (slide) ->
      # set @current to slide's index in @slides
      @current = indexOf @slides, slide

    animateSlides = (currentSlide, targetSlide, {direction, progress, durationMod}, callback) ->
      # return if an animation is in progress
      return if @currentAnimation?
      # progress and durationMod are only passed from a touch event
      progress ?= 0
      durationMod ?= 1
      # alter the duration of the animation after a touch event
      duration = Math.max 1, @opts.animationDuration * (1 - progress) * durationMod
      # slides shouldn't be prepared if this is called from a touch event
      # because this has already happened in touchStart
      console.log @currentTouchEvent?
      unless @currentTouchEvent?
        beforeFn = @opts.effect.before
        beforeFn?.call @, 0, currentSlide
        beforeFn?.call @, (if direction < 0 then 1 else -1), targetSlide
      # cache the animation state
      @currentAnimation = {start: new Date().getTime(), currentSlide, targetSlide, direction, duration, progress, callback}
      # and finally start animating
      requestAnimationFrame bind nextFrame, @

    nextFrame = (timestamp) ->
      # immediately call the next requestAnimationFrame
      id = requestAnimationFrame bind nextFrame, @
      anim = @currentAnimation
      # calculate the actual progress (fraction of the animationDuration)
      progress = Math.min 1, anim.progress + (new Date().getTime() - anim.start) / anim.duration * (1 - anim.progress)
      # call the progress functions (this is where the magic happens)
      progressFn = @opts.effect.progress
      progressFn?.call @, 0, progress * anim.direction, anim.currentSlide
      progressFn?.call @, 1, progress * anim.direction, anim.targetSlide
      if progress >= 1
        # the animation has ended
        @currentAnimation = null
        cancelAnimationFrame id
        # call the after and callback functions
        afterFn = @opts.effect.after
        afterFn?.call @, 0, anim.currentSlide
        afterFn?.call @, 1, anim.targetSlide
        anim.callback?()
        # set the new currentSlide
        setCurrentSlide.call @, anim.targetSlide

    touchstart = (event) ->
      # do nothing if an animation or touch event is currently in progress
      return if @currentAnimation? or @currentTouchEvent?
      # get the relevant slides
      currentSlide = @getCurrentSlide()
      prevSlide = @getPrevSlide()
      nextSlide = @getNextSlide()
      # prepare the slides to be animated
      beforeFn = @opts.effect.before
      beforeFn?.call @, 0, currentSlide
      beforeFn?.call @, -1, prevSlide
      beforeFn?.call @, 1, nextSlide
      # cache the touch event state
      @currentTouchEvent = {
        currentSlide
        prevSlide
        nextSlide
        touchStart: event.timeStamp
        touchX: event.touches[0].pageX
        touchY: event.touches[0].pageY
      }
      # prevent default behavior if it's set in options
      event.preventDefault() if @opts.preventScroll

    touchmove = (event) ->
      # do nothing if an animation is in progress, or there's no touch event in progress yet (which souldn't happen)
      return if @currentAnimation or not @currentTouchEvent?
      touch = @currentTouchEvent
      # calculate the progress based on the distance touched
      progress = (event.touches[0].pageX - touch.touchX) / @el.clientWidth
      # animate the slide
      requestAnimationFrame =>
        progressFn = @opts.effect.progress
        progressFn.call @, 0, progress, touch.currentSlide
        progressFn.call @, 1, progress, if progress < 0 then touch.nextSlide else touch.prevSlide
      # prevent default behavior if it's set in options
      event.preventDefault() if @opts.preventScroll

    touchend = (event) ->
      # do nothing if an animation is in progress, or there's no touch event in progress yet (which souldn't happen)
      return if @currentAnimation or not @currentTouchEvent?
      touch = @currentTouchEvent
      # calculate the final progress that has been made
      progress = (event.changedTouches[0].pageX - touch.touchX) / @el.clientWidth
      # calculate the time passed
      timePassed = event.timeStamp - touch.touchStart
      progressAbs = Math.abs progress
      # check progress and timePassed against the conditions
      for cond in @opts.conditions
        if progressAbs > cond.distance and timePassed < (cond.time ? Infinity)
          # one condition passed so set durationMod from that condition
          durationMod = cond.durationMod ? 1
          break
      # at this point, durationMod is only set if we matched a condition
      # so slide to the next slide
      if durationMod?
        # we matched a condition, so slide away the currentSlide and slide in
        # the targetSlide. if we slided to the left, the nextSlide will be the
        # targetSlide, else the prevSlide will be.
        currentSlide = touch.currentSlide
        if progress < 0
          direction = -1
          targetSlide = touch.nextSlide
        else
          direction = 1
          targetSlide = touch.prevSlide
        progress = progressAbs
      else
        # we didn't match a condition, so slide the currentSlide back into
        # position and slide targetSlide (nextSlide or prevSlide, depending on
        # slide direction) away
        targetSlide = touch.currentSlide
        if progress < 0
          direction = 1
          currentSlide = touch.nextSlide
        else
          direction = -1
          currentSlide = touch.prevSlide
        progress = 1 - progressAbs
      # call the animateSlides function with the parameters
      animateSlides.call @, currentSlide, targetSlide, {direction, progress, durationMod}, => @currentTouchEvent = null
      # prevent default behavior if set in options
      event.preventDefault() if @opts.preventScroll

    # end private methods

    # public methods

    # get*Slide all return an HTMLElement

    # get the slide at index i
    # getSlide(-1) === getSlide(slides.length - 1)
    # and getSlide(slides.length) === getSlide(0)
    getSlide: (i) ->
      i = i % @slides.length
      if i < 0 then i += @slides.length
      @slides[i]

    # get the currently visible slide
    getCurrentSlide: ->
      @slides[@current]

    # get the slide after the currently visible one
    getNextSlide: ->
      @getSlide @current + 1

    # get the slide before the currently visible one
    getPrevSlide: ->
      @getSlide @current - 1

    # get the first slide
    getFirstSlide: ->
      @slides[0]

    # get the last slide
    getLastSlide: ->
      @slides[@slides.length - 1]

    # slideTo and slideTo* initiate an animation

    # slide to the slide at index i
    slideTo: (i, cb) ->
      return if i is @current
      currentSlide = @getCurrentSlide()
      targetSlide = @getSlide i
      # slide to left if i < @current, else slide to right
      direction = if i < @current then 1 else -1
      animateSlides.call @, currentSlide, targetSlide, {direction}, cb

    # slide to the next slide
    slideToNext: (cb) ->
      currentSlide = @getCurrentSlide()
      nextSlide = @getNextSlide()
      # slide to the left
      direction = -1
      animateSlides.call @, currentSlide, nextSlide, {direction}, cb

    # slide to the previous slide
    slideToPrev: (cb) ->
      currentSlide = @getCurrentSlide()
      prevSlide = @getPrevSlide()
      # slide to the right
      direction = 1
      animateSlides.call @, currentSlide, prevSlide, {direction}, cb

# amd, commonjs and browser environment support
do (root = this, factory) ->
  Slideshow = factory root.document
  # amd
  if typeof define is 'function' and define.amd
    define [], -> Slideshow
  # commonjs
  else if typeof exports isnt 'undefined'
    module.exports = Slideshow
  # browser
  else
    root.Slideshow = Slideshow