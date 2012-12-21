# Class to handle maninpulations specific to a canvas
class CanvasHelper

  constructor: (@canvas_element, events = false) ->
    $(@canvas_element).scaleCanvas 
      x: 0
      y: 0
      scaleX: window.scaling
      scaleY: window.scaling

    $this = this

    if events
      $(@canvas_element).jCanvas
        fromCenter: false
        click: EditorAreaEvents.click_handler
        dblclick: EditorAreaEvents.double_click_handler
        mouseover: EditorAreaEvents.mouse_over_handler
        mouseout: EditorAreaEvents.mouse_out_handler
    else
      $(@canvas_element).jCanvas
        fromCenter: false
        strokeWidth: 1

  # Render all jcanvas layers in this layer
  draw_layers: () ->
    $(@canvas_element).drawLayers()

  # Clear all the layers in this canvas
  clear: () ->
    $(@canvas_element).clearCanvas()

  draw_bounds_markers: (bounds, stroke_style) ->
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
      $(@canvas_element).drawRect
        strokeStyle: stroke_style
        x: point.x - 0.5
        y: point.y - 0.5
        width: 6
        height: 6
        fromCenter: true

  draw_bounds: (bounds, stroke_style = Color.BLUE) ->
    $(@canvas_element).drawRect
      strokeStyle: stroke_style
      x: bounds.left - 2.5
      y: bounds.top - 2.5
      width: bounds.right - bounds.left + 4
      height: bounds.bottom - bounds.top + 4

  draw_selection: (bounds, stroke_style = Color.BLUE) ->
    this.draw_bounds_markers bounds, stroke_style
    this.draw_bounds bounds, stroke_style

  draw_filled_rectangle: (bounds, fill_color = Color.FILL_BLUE) ->   
    $(@canvas_element).drawRect
      fillStyle: fill_color
      x: bounds.left
      y: bounds.top
      width: bounds.right - bounds.left,
      height: bounds.bottom - bounds.top

  create_gradient: (gradient, bounds) ->
    fillStyle = null
    if gradient.type == 'linear'
      y2 = bounds.top * Math.sin(gradient.angle * 3.14 / 180)
      y1 = bounds.bottom * Math.sin(gradient.angle * 3.14 / 180)
      x2 = bounds.left * Math.cos(gradient.angle * 3.14 /180)
      x1 = bounds.right * Math.cos(gradient.angle * 3.14 / 180)

      gradient_args = 
        x1: Math.round x1
        y1: Math.round y1
        x2: Math.round x2
        y2: Math.round y2
      
      color_stops = []
      pos = 1
      for color_stop in gradient.color_stops
        tokens = color_stop.split ' '
        color = tokens[0]
        stop = tokens[1].split('%')[0]/100
        gradient_args["c#{pos}"] = color
        gradient_args["s#{pos}"] = stop
        pos++

      fillStyle = $(@canvas_element).createGradient gradient_args

    return fillStyle

  # Methods to add text, shape and image layers to a canvas
  add_text_layer: (canvas_data) ->
    $(@canvas_element).addLayer
      method: 'drawText'
      group: 'text'
      name: canvas_data.name
      fillStyle: canvas_data.fillStyle
      maxWidth: canvas_data.width
      x: canvas_data.bounds.left
      y: canvas_data.bounds.top
      font: canvas_data.font
      text: canvas_data.text

  add_shape_layer: (canvas_data) ->
    $(@canvas_element).addLayer
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

  add_image_layer: (canvas_data) ->
    $(@canvas_element).addLayer
      method: 'drawImage'
      group: 'image'
      name: canvas_data.name
      source: canvas_data.src
      x: canvas_data.bounds.left
      y: canvas_data.bounds.top

window.CanvasHelper = CanvasHelper