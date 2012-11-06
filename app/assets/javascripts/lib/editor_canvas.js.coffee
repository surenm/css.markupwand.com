class EditorCanvas
  constructor: (@canvas_element) ->
    this.drawDebugRectange()

  drawDebugRectange: ->
    $(@canvas_element).drawRect 
      strokeStyle: "#000"
      x: 20 
      y: 20
      width: 300,
      height: 200,
      fromCenter: false

  drawBounds: (bounds) ->
    $(@canvas_element).clearCanvas()

    $(@canvas_element).drawRect
      strokeStyle: "#333"
      x: bounds.left
      y: bounds.top
      width: bounds.right - bounds.left,
      height: bounds.bottom - bounds.top,
      fromCenter: false


window.EditorCanvas = EditorCanvas