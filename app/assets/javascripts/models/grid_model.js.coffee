class GridModel extends Backbone.Model
  urlRoot: "/grids"
  
  defaults:
    css: {}
    id: null
    html: ""
    layer_id: null
  
  initialize: () ->
    css = this.get "css"
    
    styles = []
    for style_key, style_value of css
      style = {}
      style.key = style_key
      style.value = style_value
      styles.push style
    
    @styleCollection = new StyleCollection
    @styleCollection.reset styles

window.GridModel = GridModel
