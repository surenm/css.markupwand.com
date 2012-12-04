#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class EditorApp
  constructor: () ->
    # design_data and sif_data are defined in import.html.erb
    @design = new DesignModel(design_data, sif_data)
    
  load_grouping_view: ->
    @grouping_view = new GroupingView({model: @design})

  load_layers_view: ->
    @layers_view = new LayersView(({model: @design}))
    
    
$(document).ready ->
  window.app = new EditorApp()

  # Initiate router 
  window.router = new EditorRouter

  Backbone.history.start()