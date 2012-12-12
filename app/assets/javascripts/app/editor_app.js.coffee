#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class EditorApp
  constructor: () ->
    # design_data and sif_data are defined in import.html.erb
    @design = new DesignModel(design_data, sif_data)
    
    this.init_editor_canvas()

    $this = this
    $.doTimeout 5000, () ->
      $this.render_design_layers()

  get_canvas: (canvas_name) ->
    canvas = $("##{canvas_name}").first()
    return canvas

  init_editor_canvas: () ->
    design_canvas = this.get_canvas('design-canvas')
    events_canvas = this.get_canvas('events-canvas')
    @editor_canvas = new EditorCanvas(design_canvas, events_canvas)

  render_design_layers: () ->
    layers = @design.layers.toArray().reverse()
    for i in [0..layers.length-1]
      this.editor_canvas.addLayer layers[i]

    this.editor_canvas.renderLayers()
    
  load_grouping_view: ->
    @grouping_view = new GroupingView({model: @design})  
    
$(window).load ->
  window.app = new EditorApp()

  # Initiate router 
  window.router = new EditorRouter

  Backbone.history.start()