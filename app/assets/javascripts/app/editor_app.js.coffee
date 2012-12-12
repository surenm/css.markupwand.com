#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class EditorApp
  constructor: () ->
    @design = window.design
    @editor_canvas = new EditorCanvas()

    $this = this

    dfd = $("#design-images").imagesLoaded()
    dfd.done (images) ->
      $this.render_design_layers()

    dfd.progress (isBroken, $images, $proper, $broken) ->
      console.log( 'Loading progress: ' + ( $proper.length + $broken.length ) + ' out of ' + $images.length );


  render_design_layers: () ->
    layers = @design.layers.toArray().reverse()
    for i in [0..layers.length-1]
      this.editor_canvas.addLayer layers[i]

    this.editor_canvas.renderLayers()
    
  load_grouping_view: ->
    @grouping_view = new GroupingView({model: @design})  
    
$(window).load ->
  # design_data and sif_data are defined in import.html.erb
  window.design = new DesignModel(design_data, sif_data)

  # initiate editor app
  window.app = new EditorApp()

  # Initiate router 
  window.router = new EditorRouter

  Backbone.history.start()