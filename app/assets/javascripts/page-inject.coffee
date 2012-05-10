addHoverListeners =->
  $('body *').bind 'hover', ->
    $('.goyaka-hover').removeClass 'goyaka-hover'
    $(this).addClass 'goyaka-hover'
    
  
getXPath = (element)->
  if element.id != ''
    return 'id(' + element.id + ')'
  
  if element == document.body
    return element.tagName
  
  ix = 0;
  siblings = element.parentNode.childNodes
  for sibling in siblings
    if sibling == element
      return getXPath(element.parentNode) + '/' + element.tagName + '[' + (ix+1) + ']'
    if sibling.nodeType == 1 and sibling.tagName == element.tagName
      ix++
      

addClickListeners =->
  $('body *').bind 'click', (e)->
    $('.goyaka-select').removeClass 'goyaka-select'
    $(this).addClass 'goyaka-select'
    currentXPath  = getXPath(this)
    currentTag    = this.tagName.toLowerCase()
    parent.updateSelected(currentTag, currentXPath)
    return false
  
  
  $(window).keydown (e) ->
    if (navigator.userAgent.indexOf('Mac OS X') != -1) and (e.metaKey)
      parent.enableMultiSelect()
    else if  (navigator.userAgent.indexOf('Mac OS X') == -1) and (e.ctrlKey)
      # Non-mac browsers. Not tested yet.
      parent.enableMultiSelect()
              
init =->
  addHoverListeners()
  addClickListeners()
  
$(document).ready ->
  init()