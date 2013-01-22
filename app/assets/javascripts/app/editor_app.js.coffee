#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class EditorApp
  el: "#editor"

  constructor: () ->
    @design = window.design

    # populate the editor
    editor_area_html = $("#editor-template").html()
    $(this.el).html editor_area_html

    @editor_area = new EditorArea()
    $this = this

    dfd = $("#design-images").imagesLoaded()
    dfd.done (images) ->
      # Load all grouping boxes, layers and intersections all at once
      $this.add_canvas_layers()
      $this.editor_area.render_layers()

    dfd.progress (isBroken, $images, $proper, $broken) ->
      console.log( 'Loading progress: ' + ( $proper.length + $broken.length ) + ' out of ' + $images.length );

  add_canvas_layers: () ->
    # first of all show all photoshop layers
    layers = @design.layers.toArray().reverse()
    for i in [0..layers.length-1]
      this.editor_area.add_layer layers[i]  

    # Second show all grouping boxes
    grouping_boxes = @design.grouping_boxes.toArray()
    #for i in [0..grouping_boxes.length-1]
    #  this.editor_area.addGroupingBox grouping_boxes[i]

  show_notification: (message)->
    notif = $("#editor-notifications")
    notif.html(message)
    notif.show()

  hide_notification: (message)->
    notif = $("#editor-notifications")
    if message == undefined
      notif.hide()
    else
      notif.html(message)
      setTimeout((->notif.hide()), 1000)

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

  load_layers_view: ->
    @layers_view = new LayersView({model: @design})
    
$(window).load ->

  # design_data and sif_data are defined in import.html.erb
  window.design = new DesignModel(design_data)

  # initiate editor app
  window.app = new EditorApp()

  # Initiate router 
  window.router = new EditorRouter

  Backbone.history.start()