#= require '../lib/editor_area_events'
#= require '../lib/canvas_helper'

class EditorArea
  constructor: (@el) ->
    # first instantiate the editor html inside the html element passed in.
    $(this.el).html $("#editor-template").html()

    # instantiate CanvasHelpers for all canvases
    @design = window.design
    @design_canvas = new CanvasHelper this.get_canvas('design-canvas'), @design.get('scaling'), true
    @events_canvas = new CanvasHelper this.get_canvas('events-canvas'), @design.get('scaling')
    @animate_canvas = new CanvasHelper this.get_canvas('animate-canvas'), @design.get('scaling')

    # wait for all design images to be loaded into the page and then render all layers
    $this = this
    dfd = $("#design-screenshot").imagesLoaded()
    dfd.done (images) ->
      $this.init_design_layers()
      $this.render_layers()

    dfd.progress (isBroken, $images, $proper, $broken) ->
      console.log( 'Loading progress: ' + ( $proper.length + $broken.length ) + ' out of ' + $images.length );

    @selected_layers = []

  # Get a canvas element given its ID
  get_canvas: (canvas_name) ->
    canvas = $("##{canvas_name}").first()
    return canvas

  # Given a design, add all its layers to the editor canvas.
  # Assumes all assets are loaded for the same
  init_design_layers: () ->
    @design_canvas.add_eventless_image_layer @design.to_canvas_data()

    layers = @design.layers.toArray().reverse()
    for i in [0..layers.length-1]
      this.add_layer layers[i]

  # When multi selecting, add a layer to selected layers
  add_to_selected_layers: (layer) ->
    if _.isEqual(layer.get('bounds'), @design.get_bounds())
      this.reset_selected_layers()
      return
      
    @selected_layers.push layer.get('id')
    @selected_layers = @selected_layers.unique()

  get_selected_layers: ->
    layers = []
    for selected_layer in @selected_layers
      layers.push @design.get_layer(selected_layer) 

    return layers

  # On disabling multiselect, reset selected layers array
  reset_selected_layers: () ->
    @selected_layers = []

  # Add a photoshop layer to this editor
  add_layer: (layer) ->
    canvas_data = layer.to_canvas_data @design_canvas
    
    if not canvas_data?
      return

    @design_canvas.add_meta_layer canvas_data
    return

  # Render all layers of the PSD in this editor
  render_layers: () ->
    @design_canvas.draw_layers()

  get_object_from_name: (object_name) ->
    tokens = object_name.split '_'
    type = tokens[0]
    id = tokens[1]
    switch type
      when 'l'
        object = app.design.get_layer(id)
      when 'g'
        object = app.design.get_grouping_box(id)

  set_zoom: (scale = 1) ->
    @design_canvas.change_scale scale
    @events_canvas.change_scale scale
    @animate_canvas.change_scale scale

    this.init_design_layers()
    this.render_layers()



window.EditorArea = EditorArea