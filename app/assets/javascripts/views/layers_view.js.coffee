#= require './view'

class LayersView extends View
  el: "#layers"
  
  initialize: ->
    this.canvas = new EditorCanvas(this.get_canvas('main-canvas'))
    this.render()

  render: ->
    $this = this
    scaling_factor = 1200/this.model.get('width')
    this.model.layers.map (layer) ->
      scaled_bounds = BoundingBox.scaled_to layer.get('bounds'), scaling_factor
      $this.canvas.drawBounds scaled_bounds



window.LayersView = LayersView