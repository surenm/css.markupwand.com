class EditorApp
  constructor: (design_target, iframe_target, grid_target) ->
    @editor_iframe = new EditorIframeView({el: iframe_target})
    @router = new EditorRouter
  
  load_design: () ->
    designCollection = new Backbone.Collection;
    designCollection.model = DesignModel;
    designCollection.reset(designs);
    
    @design = designCollection.at 0

    @design_view = new DesignView({el: "#editor-header", model: @design})    
    @editor_iframe.load_design @design
        
$(document).ready ->
  editor_app = new EditorApp("#editor-header", "#editor-iframe", "")
  window.app = editor_app
  
  Backbone.history.start()

    
  
  