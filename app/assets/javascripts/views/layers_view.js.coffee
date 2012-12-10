#= require './view'

class LayersView extends View
  el: "#layers"
  
  initialize: ->
    @canvas_element = this.get_canvas('main-canvas')
    this.canvas = new EditorCanvas(this.get_canvas('main-canvas'))
    this.render()

  render: ->
    layers = this.model.layers.toArray().reverse()
    for i in [0..layers.length-1]
      layer = layers[i]
      this.render_layer(layer)

    $(@canvas_element).drawLayers()
    $canvas_element = @canvas_element
      
  render_layer: (layer) ->
    canvas_data = layer.to_canvas_data()
    $this = this

    $canvas_element = @canvas_element
    switch layer.get('type')
      when 'text'
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
          fromCenter: false

      when 'shape'
        console.log ''
      when 'normal'
        $(@canvas_element).addLayer
          method: 'drawImage'
          group: 'image'
          name: canvas_data.name
          source: canvas_data.src
          x: canvas_data.bounds.left
          y: canvas_data.bounds.top
          fromCenter: false
          index: 0
            
window.LayersView = LayersView