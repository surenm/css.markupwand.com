iframe_doc =->
  $($("#editor-iframe").contents())

showStyles = (node)->
  $(node).parent().parent().find('pre').hide()
  $(node).parent().find('pre').show()

addFocusOverlay = (node)->
  offset = $(node).offset()
  focus_overlay_div = document.createElement 'div'
  $(focus_overlay_div).addClass 'focus-overlay'
  iframe_doc().find('body').append focus_overlay_div
  $(focus_overlay_div).css "top", offset.top - 5
  $(focus_overlay_div).css "left", offset.left - 5 
  $(focus_overlay_div).width $(node).outerWidth() + 10 
  $(focus_overlay_div).height $(node).outerHeight() + 10

clearFocusOverlays =->
  iframe_doc().find('.focus-overlay').remove()

addFocusListeners =->
  $('#css_editor input').focus( ->
    showStyles(this)
    selector_nodes = $(iframe_doc()).find('body').find('.' + $(this).data('original'))
    clearFocusOverlays()
    for node in selector_nodes
      addFocusOverlay(node)
  )

window.iframeLoaded =->
  iframe_dom   = $($("#editor-iframe").contents())
  cssLink      = document.createElement("link")
  cssLink.id   = "debug-css"
  cssLink.href = "/assets/app/iframe.css"
  cssLink.rel  = "stylesheet"
  cssLink.type = "text/css"
  $(iframe_doc()).find('head').append cssLink

$(document).ready ->
  addFocusListeners()
