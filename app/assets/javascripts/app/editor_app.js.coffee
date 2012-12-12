#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class EditorApp
  constructor: () ->
    # design_data and sif_data are defined in import.html.erb
    @design = new DesignModel(design_data, sif_data)
    
  load_grouping_view: ->
    @grouping_view = new GroupingView({model: @design})
    this.init_editor_canvas()

    $this = this
    $.doTimeout 5000, () ->
      $this.render_design_layers()
  init_editor_canvas: () ->
    layers_canvas = this.get_canvas('design-canvas')
    events_canvas = this.get_canvas('events-canvas')
    @editor_canvas = new EditorCanvas(layers_canvas, events_canvas)
    
    
$(window).load ->
  window.app = new EditorApp()

  # Initiate router 
  window.router = new EditorRouter

  Backbone.history.start()