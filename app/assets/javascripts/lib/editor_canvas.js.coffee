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


window.EditorCanvas = EditorCanvas