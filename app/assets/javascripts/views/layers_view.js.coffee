#= require './view'

class LayersView extends View
  el: "#layers"
  
  initialize: ->
    this.editor_canvas = new EditorCanvas(this.get_canvas('main-canvas'))
    this.render()

  render: ->
    layers = this.model.layers.toArray().reverse()
    for i in [0..layers.length-1]
      this.editor_canvas.addLayer layers[i]

    this.editor_canvas.renderLayers()

window.LayersView = LayersView