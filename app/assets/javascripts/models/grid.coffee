class Grid extends Backbone.Model
  urlRoot: '/grids'
  
  defaults:
    css: {}
    id: null
    html: ""
  
  initialize: () ->
    console.log "Hello fucking world"
    
grid = new Grid
console.log grid.save()
console.log grid.fetch()
console.log "hello world"