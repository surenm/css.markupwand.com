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
  $('body *').bind 'click', ->
    $('.goyaka-select').removeClass 'goyaka-select'
    $(this).addClass 'goyaka-select'
    currentXPath  = getXPath(this)
    currentTag    = this.tagName.toLowerCase()
    parent.updateSelected(currentTag, currentXPath)
    return false
    
init =->
  addHoverListeners()
  addClickListeners()
  
$(document).ready ->
  init()