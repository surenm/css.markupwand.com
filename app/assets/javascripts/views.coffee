class GenericView extends Backbone.View
  render: () ->
    template_string = $(this.template).html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context)
    
    $(this.el).html html

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
    $router = app.router
    $design = $router.design
    $.post(
      '/grids/update', 
      design: $router.design
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
    @previous_zindex = null
    
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
    
    @debug_elements = [@overlay_div, @on_focus_bar, @on_focus_bar.find("*")]
    for element in @debug_elements
      @children = @children.not element
    
    # Binding to highlight a div when hovered
    this.enable_listeners()
    
    # done editing
    @on_focus_bar.find("#done").click (event) ->
      event.stopPropagation()
      $editor_iframe.release_focus()
      
  enable_listeners: () ->
    @children.mouseenter mouseEnterHandler
    @children.mouseleave mouseLeaveHandler
    
    @children.click clickHandler
    
  disable_listeners: () ->
    @children.unbind()
  
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
    
  clear_highlights: () ->
    @children.removeClass "mouseover"

  clear_selection: () ->
    @children.removeClass "selected"
    
  focus_selected_object: (selected_object) ->
    this.disable_listeners()
    
    @overlay_div.show()
    @on_focus_bar.show()
        
    if @selected_object?
      @selected_object.removeClass "selected"
      if @previous_zindex?
        @selected_object.css "z-index", @previous_zindex
    
    @selected_object = $(selected_object);
    @previous_zindex = @selected_object.css "z-index"
    
    
  release_focus: () ->
    this.enable_listeners()
    
    this.clear_highlights()
    this.clear_selection()

    $(@overlay_div).hide()
    $(@on_focus_bar).hide()
    
    $("#editor").html("")
    
  get_grid_obj = (obj, editor) ->
    grid_id = $(obj).data('gridId')
    grid = editor.grids.get(grid_id)
    return grid

  mouseEnterHandler = (event) ->
    event.stopPropagation()
    app.editor_iframe.clear_highlights()

    $(this).addClass "mouseover"  
    
  mouseLeaveHandler = (event) ->
    event.stopPropagation()
    
  clickHandler = (event) ->
    event.stopPropagation()
    editor = app.editor_iframe
    editor.clear_highlights()
    editor.clear_selection()
    
    editor.focus_selected_object(this)
    $(this).addClass "selected"
    
    grid = get_grid_obj(this, editor)
    view = new GridView({model: grid})

  append: (element) ->  
    $(@iframe_dom).find('body').append element
    
class GridView extends GenericView
  template: "#edit-grid-properties-template"
  el: "#editor"

  events: {
    "click .show": "edit"
    "click #success": "onSuccess"
    "click #cancel": "onCancel"
  }

  initialize: () ->
    css = this.model.get("css")
    this.render()
    
  edit: (event) ->
    $(this.el).find(".form").show()
    $(this.el).find(".show").hide()
    
  onSuccess: (event) ->
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

class StyleView extends GenericView
  template: "#css-property-template"

window.DesignView = DesignView
window.EditorIframeView = EditorIframeView
window.GridView = GridView