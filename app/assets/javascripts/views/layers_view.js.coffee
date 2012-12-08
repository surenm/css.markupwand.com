#= require './view'

class LayersView extends View
  el: "#layers"
  
  initialize: ->
    @canvas_element = this.get_canvas('main-canvas')
    this.canvas = new EditorCanvas(this.get_canvas('main-canvas'))
    this.render()

  render: ->
    $this = this
    scaling_factor = 1200/this.model.get('width')

    this.model.layers.map (layer) ->
      $this.render_layer(layer)

    $(@canvas_element).drawLayers()  

  render_layer: (layer, addIndex) ->
    canvas_data = layer.to_canvas_data()

    switch layer.get('type')
      when 'text'
        $(@canvas_element).addLayer
          name: canvas_data.name
          method: 'drawText'
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
          name: canvas_data.name
          method: 'drawImage'
          source: canvas_data.src
          x: canvas_data.bounds.left
          y: canvas_data.bounds.top
          fromCenter: false


window.LayersView = LayersView