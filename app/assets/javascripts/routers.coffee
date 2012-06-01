class EditorRouter extends Backbone.Router
  routes: 
    "design/:design_id": "loadDesign"
    "design/:design_id/grid/:grid_id": "loadGrid"
    "*args": "defaultHandler"
    
  loadDesign: (design_id) ->
    console.log "Loading Design: #{design_id}"
    app.load_design design_id
  
  loadGrid: (design_id, grid_id) ->
    this.loadDesign(design_id)
    @grid = grid_id
  
  defaultHandler: (args) ->
    # Do nothing here

window.EditorRouter = EditorRouter