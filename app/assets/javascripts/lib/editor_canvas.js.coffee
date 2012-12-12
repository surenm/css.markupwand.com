class EditorCanvas
  constructor: (@canvas_element) ->
    
  drawDebugRectange: ->
    $(@canvas_element).drawRect 
      strokeStyle: "#000"
      x: 20 
      y: 20
      width: 300
      height: 200
      fromCenter: false

  clear: ->
    $(@canvas_element).clearCanvas()

  drawBounds: (bounds, stroke_color = "#33333") ->
    $(@canvas_element).drawRect
      strokeStyle: stroke_color
      x: bounds.left
      y: bounds.top
      width: bounds.right - bounds.left,
      height: bounds.bottom - bounds.top,
      fromCenter: false

  drawFilledRectangle: (bounds, fill_color = "rgba(0, 0, 0, 0.4)") ->
    $(@canvas_element).drawRect
      strokeStyle: "rgba(0, 0, 0, 0.3)"
      fillStyle: fill_color
      x: bounds.left
      y: bounds.top
      width: bounds.right - bounds.left,
      height: bounds.bottom - bounds.top,
      fromCenter: false

  createGradient: (gradient, bounds) ->
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

  renderLayers: () ->
    $(@canvas_element).drawLayers()

  addLayer: (layer) ->
    canvas_data = layer.to_canvas_data this
    
    if not canvas_data?
      return

    $this = this
    $canvas_element = @canvas_element

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
          fromCenter: false
          click: $this.layerClickHandler
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
          fromCenter: false
          click: $this.layerClickHandler
      when 'normal'
        $($canvas_element).addLayer
          method: 'drawImage'
          group: 'image'
          name: canvas_data.name
          source: canvas_data.src
          x: canvas_data.bounds.left
          y: canvas_data.bounds.top
          fromCenter: false
          click: $this.layerClickHandler

    return

  layerClickHandler: (layer) ->
    console.log layer


window.EditorCanvas = EditorCanvas