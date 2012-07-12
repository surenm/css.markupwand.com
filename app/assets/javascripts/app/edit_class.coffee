window.lastNodes = null
window.lastBackground = null

showStyles = (node)->
  console.log "hello asdf "
  $(node).parent().parent().find('pre').hide()
  $(node).parent().find('pre').show()


addFocusListeners =->
  $('#css_editor input').focus( ->
  	if (window.lastNodes != null)
      console.log window.lastNodes
      window.lastNodes.css('background-color', window.lastBackground)

    window.lastNodes      = $($("#editor-iframe").contents()).find('body').find('.' + $(this).data('original'))
    window.lastBackground = window.lastNodes.css('background-color')
    window.lastNodes.css('background-color', 'red')
    
    showStyles(this)
  )

$(document).ready ->
  addFocusListeners()