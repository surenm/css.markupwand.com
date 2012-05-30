$(document).ready ->
  editor_router = new EditorRouter("#editor-iframe")
  Backbone.history.start();

  editor_header = new EditorHeaderView({model: null, el: "#editor-header", design: editor_router.design})
    
  
  