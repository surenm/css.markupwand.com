window.updateSelected = (tag, xpath)->
  if window.Goyaka['multiSelectEnabled']
    $('.group-tags-block').html($('.group-tags-block').html() + ' hello ')
  else
    $('#tag-switcher').val(tag)
    $('#item-xpath').html(xpath)
    
window.Goyaka = {}

window.Goyaka['multiSelectEnabled'] = false  
window.enableMultiSelect = ->
  if $('.multiselect').css('visibility') == 'hidden'
    $('.multiselect').css('visibility','visible')
    $('.edit-tags').hide()
    $('.grouptags').show()
    window.Goyaka['multiSelectEnabled'] = true
    $('.group-tags-block').html('')
  else
    $('.edit-tags').show()
    $('.grouptags').hide()
    $('.multiselect').css('visibility','hidden')
    window.Goyaka['multiSelectEnabled'] = false

hoverEnter = (event) ->
  event.stopPropagation()
  grid_id = $(this).data('gridId')
  console.log "Entering #{grid_id}}"
  $(this).css("border", "2px dotted #000000")

hoverLeave = (event) ->
  event.stopPropagation()
  grid_id = $(this).data('gridId')
  console.log "Leaving #{grid_id}}"
  $(this).css "border", "0px"
 
  

$(document).ready ->  
  $(window).keydown (e) ->
    if (navigator.userAgent.indexOf('Mac OS X') != -1) and (e.altKey)
      window.enableMultiSelect()
    else if  (navigator.userAgent.indexOf('Mac OS X') == -1) and (e.ctrlKey)
      # Non-mac browsers. Not tested yet.
      window.enableMultiSelect()
    return true