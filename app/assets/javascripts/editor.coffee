$(document).ready ->
  editor_router = new EditorRouter("#editor-iframe")
  Backbone.history.start();