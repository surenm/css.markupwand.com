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

class StyleModel extends Backbone.Model
  defaults:
    key: null
    value: null
    widgetType: WidgetType.TEXT
    

window.WidgetType = WidgetType      
window.GridModel = GridModel
window.DesignModel = DesignModel
window.StyleModel = StyleModel