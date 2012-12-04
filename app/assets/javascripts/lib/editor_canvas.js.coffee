class EditorCanvas
  constructor: (@canvas_element) ->
    

  drawDebugRectange: ->
    console.log @canvas_element
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



window.EditorCanvas = EditorCanvas