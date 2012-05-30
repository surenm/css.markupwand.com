$(document).ready ->
  editor_router = new EditorRouter("#editor-iframe")
  Backbone.history.start();

  editor_header = new EditorHeaderView({model: null, el: "#editor-header", router: editor_router})
    
  
  