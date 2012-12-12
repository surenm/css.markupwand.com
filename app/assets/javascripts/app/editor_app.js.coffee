#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class EditorApp
  constructor: () ->
    # design_data and sif_data are defined in import.html.erb
    @design = new DesignModel(design_data, sif_data)
    @editor_canvas = new EditorCanvas()

    $this = this
    $.doTimeout 5000, () ->
      $this.render_design_layers()

  

  init_editor_canvas: () ->
    

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