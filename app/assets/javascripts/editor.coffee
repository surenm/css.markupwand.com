class EditorRouter extends Backbone.Router
  routes: 
    "design/:design_id": "loadDesign"
    "design/:design_id/grid/:grid_id": "loadGrid"
    "*args": "defaultHandler"
  
  loadDesign: (design_id) ->
    console.log "Design: #{design_id}"
  
  loadGrid: (design_id, grid_id) ->
    this.loadDesign(design_id)
    console.log "Grid: #{grid_id}"
  
  defaultHandler: (args) ->
    # Do nothing here

class EditorIframe extends Backbone.View
  initialize: (args) ->
    this.render()
  
  render: (url = null) ->
    if not url?
      return

    # TODO: Part of this has to move to events. But dunno how to bind events within the iframe using backbone
    @iframe_dom = $(this.el).contents()
    @children = @iframe_dom.find("div,p")

    # Adding debug stylesheet
    this.add_debug_stylesheet() 
    
    # Binding to highlight a div when hovered
    @children.mouseenter {editor: this}, mouseEnterHandler
    @children.mouseleave {editor: this}, mouseLeaveHandler
    
    # Click handler
    @children.click {editor: this}, clickHandler
  
  add_debug_stylesheet: () ->
    cssLink = document.createElement("link")

    cssLink.href = "/assets/iframe.css"
    cssLink.rel  = "stylesheet"
    cssLink.type = "text/css"

    $(@iframe_dom).find('body').append(cssLink)
    
  set_url: (url) ->
    console.log "Trying to load the iframe with #{url}"
    this.el.src = url
    $editor_iframe = this
    $(this.el).load ->
      $editor_iframe.render()
    
  set_url_for_design: (design_id, grid_id = null) ->
    url = "http://localhost:3000/generated/#{design_id}/index.html"
    if grid_id?
      url = "#{url}/grid/#{grid_id}"
    
    this.set_url url
    
  
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