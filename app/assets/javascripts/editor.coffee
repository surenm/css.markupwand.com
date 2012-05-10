window.updateSelected = (tag, xpath)->
  $('#tag-switcher').val(tag)
  $('#item-xpath').html(xpath)
  
window.enableMultiSelect = ->
  console.log "Enabled multi select"

$(document).ready ->
  
  $(window).keydown (e) ->
    if (navigator.userAgent.indexOf('Mac OS X') != -1) and (e.metaKey)
      window.enableMultiSelect()
    else if  (navigator.userAgent.indexOf('Mac OS X') == -1) and (e.ctrlKey)
      # Non-mac browsers. Not tested yet.
      window.enableMultiSelect()