#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class ImporterApp
  constructor: () ->
    # design_data and sif_data are defined in import.html.erb
    @design = new DesignModel(design_data, sif_data)
    @router = new ImporterRouter

  load_design_sidebar: (context) ->
    @sidebar_view.close() if @sidebar_view?
    @sidebar_view = new SidebarView({model: @design, context: context})
    
$(document).ready ->
  window.app = new ImporterApp()
  
  Backbone.history.start()

    
  
  
