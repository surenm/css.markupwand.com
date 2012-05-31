class EditorRouter extends Backbone.Router
  initialize: (iframe_target) ->
    @editor_iframe = new EditorIframeView({el: iframe_target})
    @editor_header = new EditorHeaderView({el: "#editor-header", router: self})
    
  routes: 
    "design/:design_id": "loadDesign"
    "design/:design_id/grid/:grid_id": "loadGrid"
    "*args": "defaultHandler"
    
  loadDesign: (design_id) ->
    console.log "Loading Design: #{design_id}"
    @design = design_id
    @editor_iframe.set_url_for_design design_id
  
  loadGrid: (design_id, grid_id) ->
    this.loadDesign(design_id)
    @grid = grid_id
  
  defaultHandler: (args) ->
    # Do nothing here

window.EditorRouter = EditorRouter