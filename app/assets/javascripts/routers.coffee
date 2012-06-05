class EditorRouter extends Backbone.Router
  routes: 
    "": "loadDesign"
    "grid/:grid_id": "loadGrid"
    "*args": "defaultHandler"
    
  loadDesign: () ->
    app.load_design()
  
  loadGrid: (design_id, grid_id) ->
    this.loadDesign(design_id)
    @grid = grid_id
  
  defaultHandler: (args) ->
    # Do nothing here

window.EditorRouter = EditorRouter