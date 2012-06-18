class GenericView extends Backbone.View
  render: () ->
    template_string = $(this.template).html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context)
    
    $(this.el).html html
  
  close: () ->
    $(this.el).unbind()

class DesignView extends GenericView
  template: "#editor-header-template"
    
  defaults:
    name: "",
    psd_file_path: ""
    font_map: {}
    
  initialize: (args) ->
    _.bindAll(this, 'render');
    this.model.bind("change", this.render)
    this.render()
    
  events: {
    "click #update-markup": "click_handler"
  }
  
  click_handler: (event) ->
    $editor = app.editor_iframe
    $editor.show_loading()
    
    $router = app.router
    $design = app.design
    $.post(
      "/design/#{$design.id}/update"
      (data, status, jqXHR) ->
        if data.status == "success"
          $router.loadDesign $design
    )

    # return false to the link so that it doesn't go anywhere
    return false

class EditorIframeView extends Backbone.View
  initialize: (args) ->
    this.render()
  
  reload: (args) ->
    this.el.src = this.el.src
  
  render: (url = null) ->
    if not url?
      return
      
    console.log "Trying to load the iframe with #{url}"
    this.el.src = url
    $editor_iframe = this

    @grids = new GridCollection()
    @grids.fetch({data: {design: @design.get("id")}, processData: true})
    
    @selected_object = null
    
    $(this.el).load ->
      $editor_iframe.add_debug_elements()
    
  event_listeners: () ->
    
    # TODO: Part of this has to move to events. But dunno how to bind events within the iframe using backbone
    $editor_iframe = this
    @children = @iframe_dom.find("*")
    
    @overlay_div = @iframe_dom.find("#overlay")
    $(@overlay_div).height $(@iframe_dom).height()
    $(@overlay_div).width $(@iframe_dom).width()
    
    @on_focus_bar = @iframe_dom.find("#on-focus-bar")
    
    @loading_div = @iframe_dom.find("#loading")
    
    @focus_overlay = @iframe_dom.find("#focus-overlay")
    
    @debug_elements = [@overlay_div, @on_focus_bar, @on_focus_bar.find("*")]
    for element in @debug_elements
      @children = @children.not element
    
    # Binding to highlight a div when hovered
    this.enable_listeners()
          
  enable_listeners: () ->
    @children.mouseenter mouseEnterHandler
    @children.mouseleave mouseLeaveHandler
    
    @children.click clickHandler
    
  disable_listeners: () ->
    @children.unbind()
    
  show_loading: ()->
    @loading_div.show()
  
  hide_loading: ()->
    @loading_div.hide()
  
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

    $("#overlay, #on-focus-bar").ready ->
      $editor_iframe.event_listeners()

  load_design: (design) ->
    @design = design
    design_id = @design.get("id")
    url = "/generated/#{design_id}/index.html"    
    this.render url
    
  clear_mouseover: () ->
    @iframe_dom.find(".mouseover").children().first().unwrap()

  clear_selection: () ->
    @children.removeClass "selected"
    
  focus_selected_object: (selected_object) ->
    # Disable listening to events in the iframe 
    this.disable_listeners()
    
    # Clear other selected elements from the iframe
    this.clear_mouseover()
    this.clear_selection()
    
    # show overlay div and on focus bar
    @overlay_div.show()
    @on_focus_bar.show()
    
    @selected_object = $(selected_object);
    @selected_object.addClass "selected"
    
    @selected_object.wrap("<div class='focus-overlay' />")
    $focus_overlay = @iframe_dom.find(".focus-overlay")

    $focus_overlay.height $focus_overlay.outerHeight() + 10
    $focus_overlay.width $focus_overlay.outerWidth() + 10
    
  release_focus: () ->
    this.enable_listeners()
    
    this.clear_mouseover()
    this.clear_selection()
    
    @selected_object.unwrap()

    @overlay_div.hide()
    @on_focus_bar.hide()
    @focus_overlay.hide()
    
  get_grid_obj = (obj, editor) ->
    grid_id = $(obj).data('gridId')
    grid = editor.grids.get(grid_id)
    return grid
    
  mouseEnterHandler = (event) ->
    event.stopPropagation()
    app.editor_iframe.clear_mouseover()
    $(this).wrap("<div class='mouseover' />")
      
  mouseLeaveHandler = (event) ->
    event.stopPropagation()
    $(this).unwrap()
    
    
  clickHandler = (event) ->
    event.stopPropagation()
    editor = app.editor_iframe
        
    editor.focus_selected_object(this)
    
    grid = get_grid_obj(this, editor)
    layer_id = $(this).data('layerId')
    grid.set "layer_id", layer_id if layer_id?
    
    if editor.grid_view?
      editor.grid_view.close()
      
    editor.grid_view = new GridView({model: grid})

  append: (element) ->  
    $(@iframe_dom).find('body').append element
    
class GridView extends GenericView
  template: "#edit-grid-properties-template"
  el: "#editor"

  events: {
    "click .show": "edit"
    "click #success": "onSuccess"
    "click #cancel": "onCancel"
    "click #done": "onClose"
  }

  initialize: () ->
    css = this.model.get("css")
    this.render()
    
  edit: (event) ->
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
    app.editor_iframe.grid_view.close()

class StyleView extends GenericView
  template: "#css-property-template"

window.DesignView = DesignView
window.EditorIframeView = EditorIframeView
window.GridView = GridView