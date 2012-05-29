$(document).ready ->
  editor_header = new EditorHeaderView({model: null, el: "#editor-header"})
    
  editor_router = new EditorRouter("#editor-iframe")
  Backbone.history.start();
  
  