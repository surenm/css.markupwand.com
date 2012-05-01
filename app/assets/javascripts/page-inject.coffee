window.onload =-> 
  parent.iframeLoaded();

lastElement = null

addHoverListeners =->
  $('*').bind 'hover', ->
    if lastElement
      $(lastElement).removeClass 'goyaka-hover'
    
    $(this).addClass 'goyaka-hover'
    
    lastElement = this
  
  
init =->
  addHoverListeners()
  
$(document).ready ->
  init()