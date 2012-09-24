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
  $(focus_overlay_div).css "left", offset.left - 5
  $(focus_overlay_div).width $(node).outerWidth(false) + 10 
  $(focus_overlay_div).height $(node).outerHeight(false) + 10
  $(focus_overlay_div).css "pointer-events", "none"

clearFocusOverlays =->
  iframe_doc().find('.focus-overlay').remove()

getChosenNode =->
  id   = $('#edit-panel').data('node-id')
  type = $('#edit-panel').data('node-type')
  Design[type][id]

addListeners =->
  $("#tag-chooser").prop('disabled', true)
  $("#class-chooser").prop('disabled', true)
  helper_terms = ['nav','navbar','header','footer',
  '-inner','-wrap','-outer','profile','banner','carousel',
  'menubar', '-header', '-footer', '-body', 'container', 
  'modal', 'tab']

  helper_terms_typeahead = []

  for term in helper_terms
    helper_terms_typeahead.push({value : term})

  $("#tag-chooser").change( (e)->
    console.log($(e.target).val())
  )

  $("#class-chooser").change( (e)->
    console.log($(e.target).val())
  )

  $("#class-chooser").keyup( (e)->
    console.log($(e.target).val())
  )

clickHandler = (e)->
  e.stopPropagation();
  clearFocusOverlays()
  addFocusOverlay(e.target)
  layer_id = ($(e.target).data('layer-id'))
  grid_id  = ($(e.target).data('grid-id'))

  $("#tag-chooser").prop('disabled', false) 
  $("#class-chooser").prop('disabled', false)

  if layer_id
    class_name = Design.layers[layer_id]['class']
    tag_name   = Design.layers[layer_id]['tag']
    type       = 'layer'
    id         = layer_id
  else if grid_id
    class_name = Design.grids[grid_id]['class']
    tag_name   = Design.grids[grid_id]['tag']
    type       = 'grid'
    id         = grid_id
  else
    $("#tag-chooser").prop('disabled', true)
    $("#class-chooser").prop('disabled', true)
    tag_name = 'nil'
    class_name = ''

  $('#edit-panel').data('node-id', id)
  $('#edit-panel').data('node-type', type)
  $('#tag-chooser').val(tag_name)
  $('#class-chooser').val(class_name)

window.iframeLoaded =->
  iframe_dom   = $($("#editor-iframe").contents())
  cssLink      = document.createElement("link")
  cssLink.id   = "debug-css"
  cssLink.href = "/assets/app/iframe.css"
  cssLink.rel  = "stylesheet"
  cssLink.type = "text/css"
  $(iframe_doc()).find('head').append cssLink
  $(iframe_doc()).find('body *').click clickHandler

$(document).ready ->
  addListeners()