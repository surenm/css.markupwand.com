class DesignModel extends Backbone.Model
  defaults: 
    name: "My new website design"
    layers: {}
    fonts: {}
    grids: {}
    colors: {}
    
  initialize: () ->
    # do nothing for now here as well

class GridModel extends Backbone.Model
  
  defaults:
    css: {}
    id: null
    html: ""
  
  initialize: () ->
    # do nothing for now
    
  fetch: () ->
    
window.GridModel = GridModel
window.DesignModel = DesignModel