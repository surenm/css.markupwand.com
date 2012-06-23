class EditorRouter extends Backbone.Router
  routes: 
    "grid/:grid_id": "loadGrid"
    "*args": "defaultHandler"
    
  loadGrid: (design_id, grid_id) ->
    this.loadDesign(design_id)
    @grid = grid_id
  
  defaultHandler: (args) ->
    #console.log "Default handler, nothing to do"

window.EditorRouter = EditorRouter