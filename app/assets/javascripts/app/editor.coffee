class EditorApp
  constructor: () ->
    @router = new EditorRouter
    @design = new DesignModel(design) # design is defined in edit.html.erb
    
    @editor_iframe = new EditorIframeView({model : @design})
    @design_view = new DesignView({model: @design})
    @sidebar_view = new SidebarView({model: @design})
    
$(document).ready ->
  window.app = new EditorApp()
  
  Backbone.history.start()

    
  
  