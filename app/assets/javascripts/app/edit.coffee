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
  return Design[type][id]

showUnsavedChanges =->
  $('#unsaved-changes').show()
  $('#dom_json').val(JSON.stringify(Design))

addListeners =->
  $("#tag-chooser").prop('disabled', true)
  $("#class-chooser").prop('disabled', true)
  $("#center-align").prop('disabled', true)

  helper_terms = ['nav','navbar','header','footer',
  '-inner','-wrap','-outer','profile','banner','carousel',
  'menubar', '-header', '-footer', '-body', 'container', 
  'modal', 'tab']

  helper_terms_typeahead = []

  for term in helper_terms
    helper_terms_typeahead.push({value : term})

  $("#tag-chooser").change( (e)->
    node = getChosenNode()
    node['tag'] = $(e.target).val()
    showUnsavedChanges()
  )

  $("#class-chooser").keyup( (e)->
    node = getChosenNode()
    node['class'] = $(e.target).val()
    showUnsavedChanges()
  )

  $("#center-align").change( (e)->
    node_data = getChosenNode()
    node = ($($("#editor-iframe").contents()).find('[data-' + node_data['type'] + '-id=' + node_data['id'] + ']'))
    if node
      if $(e.target).attr("checked") == "checked"
        node.css('margin-left','auto')
        node.css('margin-right','auto')
        node_data.css['margin-left']  = 'auto'
        node_data.css['margin-right'] = 'auto'
      else
        node.css('margin-left', '0')
        node.css('margin-right', '0')
        delete node_data.css['margin-left']
        delete node_data.css['margin-right']
      
      clearFocusOverlays()
      addFocusOverlay(node)
      showUnsavedChanges()
  )


centerAligned = (grid)->
    grid['css'].hasOwnProperty('margin-left') and 
    grid['css'].hasOwnProperty('margin-right') and
    grid['css']['margin-left'] == 'auto' and
    grid['css']['margin-right'] == 'auto'

clickHandler = (e)->
  e.stopPropagation();
  clearFocusOverlays()
  addFocusOverlay(e.target)
  layer_id = ($(e.target).data('layer-id'))
  grid_id  = ($(e.target).data('grid-id'))

  $("#tag-chooser").prop('disabled', false) 
  $("#class-chooser").prop('disabled', false)
  $("#center-align").prop('disabled', false)

  if layer_id
    class_name = Design.layer[layer_id]['class']
    tag_name   = Design.layer[layer_id]['tag']
    $("#center-align").prop('disabled', true)
    type       = 'layer'
    id         = layer_id
  else if grid_id
    class_name = Design.grid[grid_id]['class']
    tag_name   = Design.grid[grid_id]['tag']
    if centerAligned(Design.grid[grid_id])
       $("#center-align").attr('checked', true)
    else
       $("#center-align").attr('checked', false)

    type       = 'grid'
    id         = grid_id
  else
    $("#tag-chooser").prop('disabled', true)
    $("#class-chooser").prop('disabled', true)
    $("#center-align").prop('disabled', true)
    $("#center-align").attr('checked', false)

    tag_name = 'nil'
    class_name = ''
    $("#css-debug").html('')

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