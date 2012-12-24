#= require '../lib/editor_area_events'
#= require '../lib/canvas_helper'

class EditorArea
  el: "#editor"

  constructor: () ->
    $this = this

    @design = window.design
    @design_canvas = new CanvasHelper this.get_canvas('design-canvas'), @design.get('scaling'), true
    @events_canvas = new CanvasHelper this.get_canvas('events-canvas'), @design.get('scaling')
    @animate_canvas = new CanvasHelper this.get_canvas('animate-canvas'), @design.get('scaling')

    @selected_layers = []

  # Get a canvas element given its ID
  get_canvas: (canvas_name) ->
    canvas = $("##{canvas_name}").first()
    return canvas

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

    switch layer.get('type')
      when 'text'
        @design_canvas.add_text_layer canvas_data
      when 'shape'
        @design_canvas.add_shape_layer canvas_data
      when 'normal'
        @design_canvas.add_image_layer canvas_data
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


window.EditorArea = EditorArea