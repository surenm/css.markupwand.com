class EditorApp
  constructor: (design_target, iframe_target, grid_target) ->
    @editor_iframe = new EditorIframeView({el: iframe_target})
    @router = new EditorRouter
  
  load_design: () ->
    @design = new DesignModel(design)
    @design_view = new DesignView({model: @design})
    @sidebar_view = new SidebarView({model: @design})
$(document).ready ->
  editor_app = new EditorApp("#editor-header", "#editor-iframe", "")
  window.app = editor_app
  
  Backbone.history.start()

    
  
  