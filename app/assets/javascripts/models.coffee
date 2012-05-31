class DesignModel extends Backbone.Model
  urlRoot: "/design"
  initialize: () ->
    # do nothing for now here as well
    this.fetch()

class GridModel extends Backbone.Model
  urlRoot: "/grids"
  
  defaults:
    css: {}
    id: null
    html: ""
  
  initialize: () ->
    # do nothing for now
    
  fetch: () ->
    
window.GridModel = GridModel
window.DesignModel = DesignModel