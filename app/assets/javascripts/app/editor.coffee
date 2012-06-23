class EditorApp
  constructor: () ->
    @router = new EditorRouter
    @design = new DesignModel(design) # design is defined in edit.html.erb
    
    @editor_iframe = new EditorIframeView({model : @design})
  
  load_design_sidebar: (context) ->
    @sidebar_view.close() if @sidebar_view?
    @sidebar_view = new SidebarView({model: @design, context: context})
    
  load_grid_sidebar: (grid) ->
    @sidebar_view.close() if @sidebar_view?
    @sidebar_view = new SidebarView({model: grid})
    
    
$(document).ready ->
  window.app = new EditorApp()
  
  Backbone.history.start()

    
  
  