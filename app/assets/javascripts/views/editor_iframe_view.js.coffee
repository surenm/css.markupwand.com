class EditorIframeView extends Backbone.View
  el: "#editor-iframe"
  
  initialize: () ->
    this.render()
    
  render: () ->
    $editor_iframe = this
    $(this.el).load ->
      $editor_iframe.add_debug_elements()
    
  reload: (args) ->
    this.el.src = this.el.src

  add_debug_elements: () ->
    @iframe_dom = $(this.el).contents()
    $editor_iframe = this

    @cssLink = document.createElement("link")
    @cssLink.id = "debug-css"
    @cssLink.href = "/assets/app/iframe.css"
    @cssLink.rel  = "stylesheet"
    @cssLink.type = "text/css"
    $(@iframe_dom).find('body').append @cssLink

    @jsLink = document.createElement("script")
    @jsLink.id = "debug-js"
    @jsLink.src = "/assets/app/iframe.js"
    @jsLink.type = "text/javascript"
    $(@iframe_dom).find('body').append @jsLink

    $("#overlay").ready ->
      $editor_iframe.event_listeners()

  event_listeners: () ->
    
    # TODO: Part of this has to move to events. But dunno how to bind events within the iframe using backbone
    $editor_iframe = this
        
    @overlay_div = @iframe_dom.find("#overlay")
    $(@overlay_div).height $(@iframe_dom).height()
    $(@overlay_div).width $(@iframe_dom).width()
    
    @loading_div = @iframe_dom.find("#loading")
    
    @children = @iframe_dom.find("body").find("[data-grid-id]")
    
    # Binding to highlight a div when hovered
    # this.enable_listeners()
          
  enable_listeners: () ->
    @children.click clickHandler
    
    @children.mouseenter mouseEnterHandler
    @children.mouseleave mouseLeaveHandler
     
  disable_listeners: () ->
    @children.unbind()
    
  show_loading: ()->
    @loading_div.show()
  
  hide_loading: ()->
    @loading_div.hide()
  
  clear_mouseover: () ->
    @iframe_dom.find(".mouse-overlay").removeClass "mouse-overlay"

  focus_selected_object: (selected_object) ->
    # Disable listening to events in the iframe 
    this.disable_listeners()
    
    # Clear other selected elements from the iframe
    this.clear_mouseover()
    
    # show overlay div and on focus bar
    #@overlay_div.show()

    @selected_object = $(selected_object);
    @selected_object.addClass "selected"
    
    offset = $(@selected_object).offset()

    if not offset?
      return

    @focus_overlay = @iframe_dom.find(".focus-overlay")

    top = offset.top - 10
    if top <= 0
      top = offset.top

    left = offset.left - 10
    if left <= 0
      left = offset.left

    @focus_overlay.css "top", top
    @focus_overlay.css "left", left
    @focus_overlay.height $(@selected_object).outerHeight() + 20
    @focus_overlay.width $(@selected_object).outerWidth() + 20
    @focus_overlay.show()

  focus_grid_object: (grid_id) ->
    grid = @iframe_dom.find("[data-grid-id='#{grid_id}']")
    this.focus_selected_object(grid)

  release_focus: () ->
    this.enable_listeners()
    this.clear_mouseover()
    @selected_object.removeClass "selected"
    #@overlay_div.hide()
    @focus_overlay.hide()
      
  get_grid_obj: (obj) ->
    grid_id = $(obj).data('gridId')
    grid = app.design.grids.get(grid_id)
    return grid
    
  mouseEnterHandler = (event) ->
    event.stopPropagation()
    app.design.editor_iframe.clear_mouseover()
    
    $(this).addClass "mouse-overlay"


  mouseLeaveHandler = (event) ->
    event.stopPropagation()
    app.design.editor_iframe.clear_mouseover()
    
  clickHandler = (event) ->
    event.stopPropagation()
    $editor = app.design.editor_iframe
    $editor.focus_selected_object(this)

  append: (element) ->  
    $(@iframe_dom).find('body').append element

window.EditorIframeView = EditorIframeView
