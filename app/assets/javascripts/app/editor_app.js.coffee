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
      # Load all grouping boxes, layers and intersections all at once
      $this.add_canvas_layers()
      $this.editor_canvas.renderLayers()

    dfd.progress (isBroken, $images, $proper, $broken) ->
      console.log( 'Loading progress: ' + ( $proper.length + $broken.length ) + ' out of ' + $images.length );

  add_canvas_layers: () ->
    # first of all show all photoshop layers
    layers = @design.layers.toArray().reverse()
    for i in [0..layers.length-1]
      this.editor_canvas.addLayer layers[i]  

    # Second show all grouping boxes
    grouping_boxes = @design.grouping_boxes.toArray()
    #for i in [0..grouping_boxes.length-1]
    #  this.editor_canvas.addGroupingBox grouping_boxes[i]

  load_intersection_view: ->
    @intersecting_pairs = new IntersectingPairsCollection()
    @intersecting_pairs.attr('design_id', @design.id)
    $app = this
    @intersecting_pairs.fetch({ 
      success: ()->
        @intersection_view = new IntersectionView({model: $app.intersecting_pairs})
      })
    return
    
  load_grouping_view: ->
    @grouping_view = new GroupingView({model: @design})
    
$(window).load ->
  meny = Meny.create
    menuElement: document.querySelector '.meny' 
    contentsElement: document.querySelector '.contents'
    threshold: 10

  # design_data and sif_data are defined in import.html.erb
  window.design = new DesignModel(design_data, sif_data)

  # initiate editor app
  window.app = new EditorApp()

  # Initiate router 
  window.router = new EditorRouter

  Backbone.history.start()