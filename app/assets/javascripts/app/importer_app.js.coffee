#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class ImporterApp
  constructor: () ->
    @router = new ImporterRouter
    #@design = new DesignModel(design)

    @design_iframe = new EditorIframeView
  
  load_design_sidebar: (context) ->
    @sidebar_view.close() if @sidebar_view?
    @sidebar_view = new SidebarView({model: @design, context: context})
    
$(document).ready ->
  window.app = new ImporterApp()
  
  Backbone.history.start()

    
  
  
