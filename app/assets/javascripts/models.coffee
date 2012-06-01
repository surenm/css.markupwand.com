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
      
window.GridModel = GridModel
window.DesignModel = DesignModel