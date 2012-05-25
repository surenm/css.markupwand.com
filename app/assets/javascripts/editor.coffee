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

class Editor
  constructor: (target) ->
    @iframe_dom = $(target).contents()
    
    this.add_editor_stylesheet()
    @children = @iframe_dom.find("div,p")
    # Binding to highlight a div when hovered
    @children.mouseenter {editor: this}, mouseEnterHandler
    @children.mouseleave {editor: this}, mouseLeaveHandler
    
    # Click handler
    @children.click {editor: this}, clickHandler
  
  add_editor_stylesheet: () ->
    cssLink = document.createElement("link")

    cssLink.href = "./assets/iframe.css"
    cssLink.rel  = "stylesheet"
    cssLink.type = "text/css"

    $(@iframe_dom).find('body').append(cssLink)
  
  clear_highlights: (target) ->
    @children.removeClass "mouseover"

  clear_selection: (target) ->
    @children.removeClass "selected"
  
  get_grid_id = (obj) ->
    grid_id = $(obj).data('gridId')
    return grid_id
    
  mouseEnterHandler = (event) ->
    event.stopPropagation()
    event.data.editor.clear_highlights()
    $(this).addClass "mouseover"  
    
  mouseLeaveHandler = (event) ->
    event.stopPropagation()
    
  clickHandler = (event) ->
    event.stopPropagation()
    editor = event.data.editor
    editor.clear_highlights()
    editor.clear_selection()
    
    $(this).addClass "selected"
    

$(document).ready ->
  $("iframe").load ->
    editor = new Editor "#editor-iframe"

  $(window).keydown (e) ->
    if (navigator.userAgent.indexOf('Mac OS X') != -1) and (e.altKey)
      window.enableMultiSelect()
    else if  (navigator.userAgent.indexOf('Mac OS X') == -1) and (e.ctrlKey)
      # Non-mac browsers. Not tested yet.
      window.enableMultiSelect()
    return true