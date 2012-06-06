class WidgetType
  TEXT: 'text'
  DROPDOWN: 'dropdown'
  COLOR: 'color'
  NUMERIC: 'numeric'
  GRADIENT: 'gradient'

class DesignModel extends Backbone.Model
  urlRoot: "/design"
  
  defaults:
    name: ""
    id: null

class GridModel extends Backbone.Model
  urlRoot: "/grids"
  
  defaults:
    css: {}
    id: null
    html: ""
  
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

class StyleModel extends Backbone.Model
  defaults:
    key: null
    value: null
    widgetType: WidgetType.TEXT
    

window.WidgetType = WidgetType      
window.GridModel = GridModel
window.DesignModel = DesignModel
window.StyleModel = StyleModel