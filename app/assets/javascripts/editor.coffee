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

$(document).ready ->
  
  $(window).keydown (e) ->
    if (navigator.userAgent.indexOf('Mac OS X') != -1) and (e.metaKey)
      window.enableMultiSelect()
    else if  (navigator.userAgent.indexOf('Mac OS X') == -1) and (e.ctrlKey)
      # Non-mac browsers. Not tested yet.
      window.enableMultiSelect()
    return true