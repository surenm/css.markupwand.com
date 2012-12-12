class EditorCanvas
  COLORS = 
    BLUE: "#0000ff"
    ORANGE: "#ff6723" 
    FILL_BLUE: "rgba(245, 245, 245, 0.2)"
    FILL_RED: "#d87272"
  
  constructor: () ->
    $this = this

    @design_canvas = this.get_canvas('design-canvas')
    @events_canvas = this.get_canvas('events-canvas')
    @animate_canvas = this.get_canvas('animate-canvas')

    $(@design_canvas).jCanvas
      fromCenter: false
      click: $this.layerClickHandler
      dblclick: $this.layerDoubleClickHandler
      mouseover: $this.layerMouseOverHandler
      mouseout: $this.layerMouseOutHandler

    $(@events_canvas).jCanvas
      fromCenter: false
      strokeWidth: 1

  get_canvas: (canvas_name) ->
    canvas = $("##{canvas_name}").first()
    return canvas

  drawDebugRectange: ->
    $(@events_canvas).drawRect 
      strokeStyle: "#000"
      x: 20 
      y: 20
      width: 300
      height: 200
      fromCenter: false

  clear: ->
    $(@events_canvas).clearCanvas()

  drawBounds: (bounds, stroke_style = COLORS.BLUE) ->
    $(@events_canvas).drawRect
      strokeStyle: stroke_style
      x: bounds.left
      y: bounds.top
      width: bounds.right - bounds.left,
      height: bounds.bottom - bounds.top,

  drawFilledRectangle: (bounds, fill_color = COLORS.FILL_BLUE) ->
    $(@events_canvas).drawRect
      fillStyle: fill_color
      x: bounds.left
      y: bounds.top
      width: bounds.right - bounds.left,
      height: bounds.bottom - bounds.top

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

      fillStyle = $(@design_canvas).createGradient gradient_args

    return fillStyle

  renderLayers: () ->
    $(@design_canvas).drawLayers()

  addLayer: (layer) ->
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

  layerClickHandler: (layer) ->
    

  layerDoubleClickHandler: (layer) ->
    

  layerMouseOverHandler: (layer) ->
    

  layerMouseOutHandler: (layer) ->
    

window.EditorCanvas = EditorCanvas