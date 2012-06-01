class DesignView extends Backbone.View
  defaults:
    name: "",
    psd_file_path: ""
    font_map: {}
    
  initialize: (args) ->
    _.bindAll(this, 'render');
    this.model.bind("change", this.render)
    
  events: {
    "click #update-markup": "click_handler"
  }
    
  render: () ->
    template_string = $("#editor-header-template").html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context)
    
    $(this.el).html html
  
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
      $editor_iframe.event_listeners()

    
  event_listeners: () ->
    # TODO: Part of this has to move to events. But dunno how to bind events within the iframe using backbone
    @iframe_dom = $(this.el).contents()
    @children = @iframe_dom.find("div,p")
    
    # Adding debug stylesheet
    this.add_debug_elements()
            
    # Binding to highlight a div when hovered
    @children.mouseenter {editor: this}, mouseEnterHandler
    @children.mouseleave {editor: this}, mouseLeaveHandler
    
    # Click handler
    @children.click {editor: this}, clickHandler    
  
  add_debug_elements: () ->
    cssLink = document.createElement("link")

    cssLink.href = "/assets/app/iframe.css"
    cssLink.rel  = "stylesheet"
    cssLink.type = "text/css"

    $(@iframe_dom).find('body').append(cssLink)
    
    @overlay_div = document.createElement("div")
    @overlay_div.id = "overlay"
    $(@overlay_div).height $(@iframe_dom).height()
    $(@overlay_div).width $(@iframe_dom).width()
    $(@overlay_div).hide()
    $(@iframe_dom).find('body').append(@overlay_div)
    
  load_design: (design) ->
    @design = design
    design_id = @design.get("id")
    url = "http://localhost:3000/generated/#{design_id}/index.html"    
    this.render url
    
  clear_highlights: (target) ->
    @children.removeClass "mouseover"

  clear_selection: (target) ->
    @children.removeClass "selected"
    
  focus_selected_object: (selected_object) ->
    $(@overlay_div).show()
    console.log $(@overlay_div).css "z-index"
    if @selected_object?
      @selected_object.removeClass "selected"
      if @previous_zindex?
        @selected_object.css "z-index", @previous_zindex
    
    @selected_object = $(selected_object);
    @previous_zindex = @selected_object.css "z-index"

    $(@selected_object).addClass "selected"
    console.log @selected_object.css("z-index")


  get_grid_obj = (obj, editor) ->
    grid_id = $(obj).data('gridId')
    grid = editor.grids.get(grid_id)
    return grid

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
    
    #editor.focus_selected_object(this)
    $(this).addClass "selected"
    
    grid = get_grid_obj(this, editor)
    view = new GridView({model: grid, el: "#editor"})
    view.render()
    
class GridView extends Backbone.View
  
  render: () ->
    template_string = $("#edit-grid-properties-template").html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context);
    $(this.el).html html


window.DesignView = DesignView
window.EditorIframeView = EditorIframeView
window.GridView = GridView