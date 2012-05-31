class EditorApp
  constructor: (design_target, iframe_target, grid_target) ->
    @editor_iframe = new EditorIframeView({el: iframe_target})
    @design_view = new DesignView({el: "#editor-header"})
    @router = new EditorRouter
        
$(document).ready ->
  editor_app = new EditorApp("#editor-header", "#editor-iframe", "")
  window.app = editor_app
  Backbone.history.start()

    
  
  