class EditorIframe extends Backbone.View
  initialize: (args) ->
    this.render()
  
  render: (url = null) ->
    if not url?
      return
      
    console.log "Trying to load the iframe with #{url}"
    this.el.src = url
    $editor_iframe = this

    @grids = new GridCollection()
    @grids.fetch({data: {design: @design}, processData: true})
    
    $(this.el).load ->
      $editor_iframe.event_listeners()
    
  event_listeners: () ->
    # TODO: Part of this has to move to events. But dunno how to bind events within the iframe using backbone
    @iframe_dom = $(this.el).contents()
    @children = @iframe_dom.find("div,p")
    
    # Adding debug stylesheet
    this.add_debug_stylesheet(@iframe_dom)
        
    # Binding to highlight a div when hovered
    @children.mouseenter {editor: this}, mouseEnterHandler
    @children.mouseleave {editor: this}, mouseLeaveHandler
    
    # Click handler
    @children.click {editor: this}, clickHandler    
  
  add_debug_stylesheet: (iframe_dom) ->
    cssLink = document.createElement("link")

    cssLink.href = "/assets/iframe.css"
    cssLink.rel  = "stylesheet"
    cssLink.type = "text/css"

    $(iframe_dom).find('body').append(cssLink)
    
  set_url_for_design: (design_id, grid_id = null) ->
    @design = design_id
    url = "http://localhost:3000/generated/#{design_id}/index.html"
    if grid_id?
      url = "#{url}/grid/#{grid_id}"
    
    this.render url
    
  clear_highlights: (target) ->
    @children.removeClass "mouseover"

  clear_selection: (target) ->
    @children.removeClass "selected"
  
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

    $(this).addClass "selected"

    grid = get_grid_obj(this, editor)
    view = new GridView({model: grid, el: "#editor"})
    view.render()
    
window.EditorIframe = EditorIframe