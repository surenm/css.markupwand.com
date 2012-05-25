class Grid extends Backbone.Model
  urlRoot: '/grids'
  
  defaults:
    css: {}
    id: null
    html: ""
  
  initialize: () ->
    console.log "Initializing a grid"