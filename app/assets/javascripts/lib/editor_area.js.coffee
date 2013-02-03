#= require '../lib/editor_area_events'
#= require '../lib/canvas_helper'

class EditorArea
  constructor: (@el) ->
    # first instantiate the editor html inside the html element passed in.
    $(this.el).html $("#editor-template").html()

    @design = window.design

    @design.set 'editor_height', $("#editor").height()
    @design.set 'editor_width', $("#editor").width()

    $(".canvas-area").height @design.get('editor_height')
    $(".canvas-area").width @design.get('editor_width')

    if @design.get('editor_width') < @design.get('width')
      editor_fit_scaling = (@design.get('editor_width') * 100)/ @design.get('width')
    else
      editor_fit_scaling = 100

    @design.set 'scaling', editor_fit_scaling

    # instantiate CanvasHelpers for all canvases
    @design = window.design
    @design_canvas = new CanvasHelper 'design-canvas', @design, true
    @events_canvas = new CanvasHelper 'events-canvas', @design
    @animate_canvas = new CanvasHelper 'animate-canvas', @design

    # wait for all design images to be loaded into the page and then render all layers
    $this = this
    dfd = $("#design-screenshot").imagesLoaded()
    dfd.done (images) ->
      $this.init_design_layers()

    dfd.progress (isBroken, $images, $proper, $broken) ->
      console.log( 'Loading progress: ' + ( $proper.length + $broken.length ) + ' out of ' + $images.length );

    @selected_layers = []

  # remove all layers from design canvas and clear all canvases
  reset_canvases: () ->
    @design_canvas.destroy()

    @design_canvas.clear()    
    @animate_canvas.clear()
    @events_canvas.clear()

  # set the zoom level for the canvas on every zoom level change
  set_zoom: (scale = 1) ->
    this.reset_canvases()

    @design_canvas.change_scale scale
    @events_canvas.change_scale scale
    @animate_canvas.change_scale scale

    if @measure_mode
      this.enable_measureit()
    else
      this.init_design_layers()

  # just reset all canvases and draw all layers with events enabled, which is the default
  enable_events: () ->
    this.reset_canvases()
    this.init_design_layers()
  
  # just reset all canvases and draw all layers with events disabled
  disable_events: () ->   
    this.reset_canvases()
    this.init_design_layers(false)

  # Given a design, add all its layers to the editor canvas.
  # Assumes all assets are loaded for the same
  init_design_layers: (enable_events = true) ->
    @design_canvas.add_image_layer @design.to_canvas_data(), false

    layers = @design.layers.toArray().reverse()
    for i in [0..layers.length-1]
      layer = layers[i]
      canvas_data = layer.to_canvas_data @design_canvas
      if not canvas_data?
        continue
      @design_canvas.add_meta_layer canvas_data, enable_events

    @design_canvas.draw_layers()

  # When multi selecting, add a layer to selected layers
  add_to_selected_layers: (layer) ->
    if _.isEqual(layer.get('bounds'), @design.get_bounds())
      this.reset_selected_layers()
      return
      
    @selected_layers.push layer.get('id')
    @selected_layers = @selected_layers.unique()

  # get list of selected layers in editor area
  get_selected_layers: ->
    layers = []
    for selected_layer in @selected_layers
      layers.push @design.get_layer(selected_layer) 

    return layers

  # On disabling multiselect, reset selected layers array
  reset_selected_layers: () ->
    @selected_layers = []

  get_object_from_name: (object_name) ->
    tokens = object_name.split '_'
    type = tokens[0]
    id = tokens[1]
    switch type
      when 'l'
        object = app.design.get_layer(id)
      when 'g'
        object = app.design.get_grouping_box(id)

  # enable a measure it plugin along with design image
  enable_measureit: () ->
    # enable measureit mode
    @measure_mode = true

    #clear all present canvases
    this.reset_canvases()

    # calculate measureit layer data at this zoom level
    measureit_layer_data = 
      name: 'measureit'
      x: 0
      y: 0
      bounds: 
        top: 0
        left: 0
        right: @design.get('width')
        bottom: @design.get('height')
      width: @design.get('width')
      height: @design.get('height')
      event_handlers:
        mousedown: EditorAreaEvents.area_select_mouse_down_handler
        mouseup: EditorAreaEvents.area_select_mouse_up_handler
        mousemove: EditorAreaEvents.area_select_mouse_move_handler
        
    @design_canvas.add_image_layer @design.to_canvas_data(), false
    @design_canvas.add_meta_layer_with_custom_events measureit_layer_data
    @design_canvas.draw_layers()

  # clear all canvases and draw back the layers
  disable_measureit: () ->
    #disable measureit mode
    @measure_mode = false

    #clear all present canvases
    this.reset_canvases()

    # draw back all layers
    this.init_design_layers()

  # area select start handler
  set_area_select_start: (start_point) ->
    @area_select_start = start_point

  set_area_select_change: (current_point) ->
    if @area_select_start?
      @animate_canvas.clear()

      bounds = 
        left: Math.min @area_select_start.x, current_point.x
        top: Math.min @area_select_start.y, current_point.y
        right: Math.max @area_select_start.x, current_point.x
        bottom: Math.max @area_select_start.y, current_point.y
      
      @animate_canvas.draw_filled_rectangle bounds, Color.LIGHTER_BLUE
      
  set_area_select_end: (end_point) ->
    @animate_canvas.clear()

    bounds = 
      left: Math.min @area_select_start.x, end_point.x
      top: Math.min @area_select_start.y, end_point.y
      right: Math.max @area_select_start.x, end_point.x
      bottom: Math.max @area_select_start.y, end_point.y

    @animate_canvas.draw_filled_rectangle bounds, Color.LIGHTER_ORANGE

    # reset select start and end points
    @area_select_start = null
    @area_select_end = null

window.EditorArea = EditorArea