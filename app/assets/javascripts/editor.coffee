window.updateSelected = (tag, xpath)->
  $('#tag-switcher').val(tag)
  $('#item-xpath').html(xpath)

window.Goyaka = {}

window.Goyaka['multiSelectEnabled'] = false  
window.enableMultiSelect = ->
  console.log "Enabled multi select"
  if $('.multiselect').css('visibility') == 'hidden'
    $('.multiselect').css('visibility','visible')
    $('.edit-tags').hide()
    $('.grouptags').show()
    window.Goyaka['multiSelectEnabled'] = true
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