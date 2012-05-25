
class EditorIframe extends Backbone.View
  initialize: () ->
    @iframe_dom = $(this.el).contents()
    
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
  editor_router = new EditorRouter
  Backbone.history.start();
  
  $("iframe").load ->
    editor_iframe = new EditorIframe({ el: "#editor-iframe"})    