#= require '../lib/editor_area_events'
#= require '../lib/canvas_helper'

class EditorArea
  el: "#editor"

  constructor: () ->
    $this = this

    @design = window.design

    @design_canvas = this.get_canvas('design-canvas')
    @events_canvas = this.get_canvas('events-canvas')
    @animate_canvas = this.get_canvas('animate-canvas')

    $('canvas').scaleCanvas 
      x: 0
      y: 0
      scaleX: window.scaling
      scaleY: window.scaling

    $(@design_canvas).jCanvas
      fromCenter: false
      click: $this.click_handler
      dblclick: $this.double_click_handler
      mouseover: $this.mouse_over_handler
      mouseout: $this.mouse_out_handler

    $(@events_canvas).jCanvas
      fromCenter: false
      strokeWidth: 1

  get_canvas: (canvas_name) ->
    canvas = $("##{canvas_name}").first()
    return canvas

  clear: ->
    $(@events_canvas).clearCanvas()
    $(@animate_canvas).clearCanvas()

  draw_bounds_markers: ( bounds, stroke_style, animate = false) ->
    $canvas = @events_canvas
    if animate
      $canvas = @animate_canvas

    points = [
      {x: bounds.left-2, y:bounds.top-2}
      {x: bounds.left-2, y:bounds.bottom+2}
      {x: bounds.right+2, y: bounds.top-2}
      {x: bounds.right+2, y: bounds.bottom+2}
      {x: (bounds.right+bounds.left)/2, y: bounds.top - 2}
      {x: (bounds.right+bounds.left)/2, y: bounds.bottom + 2}
      {x: bounds.right+2, y: (bounds.top + bounds.bottom)/ 2}
      {x: bounds.left-2, y: (bounds.top + bounds.bottom)/ 2}
    ]

    for point in points
      $($canvas).drawRect
        strokeStyle: stroke_style
        x: point.x - 0.5
        y: point.y - 0.5
        width: 6
        height: 6
        fromCenter: true

  draw_bounds: (bounds, stroke_style = COLORS.BLUE, animate = false) ->
    $canvas = @events_canvas
    if animate
      $canvas = @animate_canvas

    $($canvas).drawRect
      strokeStyle: stroke_style
      x: bounds.left - 2.5
      y: bounds.top - 2.5
      width: bounds.right - bounds.left + 4
      height: bounds.bottom - bounds.top + 4

  get_selected_layers: ->
    layers = []
    for selected_layer in @selected_layers
     layers.push @design.get_layer(selected_layer) 

    return layers

  # On disabling multiselect, reset selected layers array
  reset_selected_layers: () ->
    @selected_layers = []

  add_layer: (layer) ->
    canvas_data = layer.to_canvas_data this
    
    if not canvas_data?
      return

    $this = this
    $canvas_element = @design_canvas

    switch layer.get('type')
      when 'text'
        $($canvas_element).addLayer
          method: 'drawText'
          group: 'text'
          name: canvas_data.name
          fillStyle: canvas_data.fillStyle
          maxWidth: canvas_data.width
          x: canvas_data.bounds.left
          y: canvas_data.bounds.top
          font: canvas_data.font
          text: canvas_data.text
      when 'shape'
        $($canvas_element).addLayer
          method: 'drawRect'
          group: 'shape'
          name: canvas_data.name
          x: canvas_data.bounds.left
          y: canvas_data.bounds.top
          width: canvas_data.width
          height: canvas_data.height
          fillStyle: canvas_data.fillStyle
          strokeStyle: canvas_data.strokeStyle
          strokeWidth: canvas_data.strokeWidth
          cornerRadius: canvas_data.cornerRadius
      when 'normal'
        $($canvas_element).addLayer
          method: 'drawImage'
          group: 'image'
          name: canvas_data.name
          source: canvas_data.src
          x: canvas_data.bounds.left
          y: canvas_data.bounds.top

    return

  @get_object_from_name: (object_name) ->
    tokens = object_name.split '_'
    type = tokens[0]
    id = tokens[1]
    switch type
      when 'l'
        object = app.design.get_layer(id)
      when 'g'
        object = app.design.get_grouping_box(id)

  click_handler: (canvas_layer) ->
    layer = EditorCanvas.get_object_from_name canvas_layer.name
    $editor_canvas = app.editor_canvas
    $editor_canvas.clear()
    $editor_canvas.draw_bounds layer.get('bounds')

  double_click_handler: (layer) ->
    

  mouse_over_handler: (canvas_layer) ->
    layer = EditorCanvas.get_object_from_name canvas_layer.name
    $editor_canvas = app.editor_canvas
    $editor_canvas.draw_bounds layer.get('bounds'), COLORS.ORANGE, true
    
  mouse_out_handler: (canvas_layer) ->
    $editor_canvas = app.editor_canvas
    $editor_canvas.animate_canvas.clearCanvas()

  dummy_handler: (canvas_layer) ->

window.EditorArea = EditorArea