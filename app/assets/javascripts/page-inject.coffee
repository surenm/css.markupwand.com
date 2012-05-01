window.onload =-> 
  parent.iframeLoaded();

addHoverListeners =->
  $('body *').bind 'hover', ->
    $('.goyaka-hover').removeClass 'goyaka-hover'
    $(this).addClass 'goyaka-hover'
    
addClickListeners =->
  $('body *').bind 'click', ->
    $('.goyaka-select').removeClass 'goyaka-select'
    $(this).addClass 'goyaka-select'
    return false
    
init =->
  addHoverListeners()
  addClickListeners()
  
$(document).ready ->
  init()