class GenericView extends Backbone.View
  render: () ->
    template_string = $(this.template).html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context)
    
    $(this.el).html html
  
  close: () ->
    $(this.el).unbind()
    $(this.el).empty()

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
    this.enable_listeners()
          
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
    @iframe_dom.find(".mouseoverlay").removeClass "mouseoverlay"

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
    
    @focus_overlay = @iframe_dom.find(".focus-overlay")
    @focus_overlay.css "top", offset.top 
    @focus_overlay.css "left", offset.left
    @focus_overlay.height $(@selected_object).outerHeight() + 10
    @focus_overlay.width $(@selected_object).outerWidth() + 10
    @focus_overlay.show()
    
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
    app.editor_iframe.clear_mouseover()
    
    $(this).addClass "mouseoverlay"

  mouseLeaveHandler = (event) ->
    event.stopPropagation()
    app.editor_iframe.clear_mouseover()
    
  clickHandler = (event) ->
    event.stopPropagation()
    $editor = app.editor_iframe
        
    $editor.focus_selected_object(this)
    
    grid = $editor.get_grid_obj(this)
    layer_id = $(this).data('layerId')
    grid.set "layer_id", layer_id if layer_id?
    
    app.load_grid_sidebar grid

  append: (element) ->  
    $(@iframe_dom).find('body').append element
  

class SidebarView extends GenericView
  design_sidebar_templates: {
    default     : "#design-default-template"
    identifiers : "#design-edit-identifiers-template",
    classes     : "#design-edit-classes-template",
    tags        : "#design-edit-tags-template",
    dom         : "#design-edit-dom-template"
  }
  grid_sidebar_template: "#grid-sidebar-template"
  el: "#editor"

  events: {
    "click .grid-sidebar .show": "editGrid"
    "click .grid-sidebar #success": "onSuccess"
    "click .grid-sidebar #cancel": "onCancel"
    "click .grid-sidebar #done": "onClose"
    
    "click .design-classes .css-class": "editDesignClass"
  }

  initialize: () ->
    this.options.context = "default" if not this.options.context?

    this.render()
    
  render: () ->
    if this.model instanceof GridModel
      this.render_grid_sidebar()
    else if this.model instanceof DesignModel
      this.render_design_sidebar()
      
  render_design_sidebar: () ->
    template_id = this.design_sidebar_templates[this.options.context]
    template_string = $(template_id).html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context)

    $(this.el).html html
    if this.options.context == "dom"
      $dom_tree = $(this.el).find("#dom-tree")
      tree_data = [app.design.get("dom_tree")]
      $(this.el).ready ->
        $dom_tree.tree {
          data: tree_data
          autoOpen: true
        }

      $dom_tree.bind 'tree.click', (event) ->
        grid_id = event.node.id
        grid = app.editor_iframe.iframe_dom.find("[data-grid-id=#{grid_id}]")
        app.editor_iframe.focus_selected_object grid

  render_grid_sidebar: () ->
    template_string = $(this.grid_sidebar_template).html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context)
    
    $(this.el).html html
    
  editGrid: (event) ->
    $(this.el).find(".form").show()
    $(this.el).find(".show").hide()
    
  onSuccess: (event) ->
    $editor = app.editor_iframe
    $editor.show_loading()
    
    tag = $(this.el).find("#taginput").attr("value")
    this.model.set "tag", tag
    this.model.save({},{
      success: () ->
        app.editor_iframe.reload()
    })
    this.render()

  onCancel: (event) -> 
    $(this.el).find(".form").hide()
    $(this.el).find(".show").show()
  
  onClose: (event) ->
    event.stopPropagation()
    app.editor_iframe.release_focus()

    # if the current model is GridModel then we have to load back the design sidebar
    if this.model instanceof GridModel
      app.load_design_sidebar()
      
  editDesignClass: (event) ->
    selected_obj = event.target
    classname = $(selected_obj).data('styleClass')
    grids = app.design.get("css_classes")[classname]
    $editor_iframe = app.editor_iframe
    $.each grids, (index, value) ->
      grid = $editor_iframe.iframe_dom.find("[data-grid-id=#{value}]")
      $.each grid, () ->
        $editor_iframe.focus_selected_object this
    
window.SidebarView = SidebarView
window.EditorIframeView = EditorIframeView
