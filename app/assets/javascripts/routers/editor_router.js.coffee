class EditorRouter extends Backbone.Router
  routes:
    "" : "defaultHandler"
    "grouping" : "groupingHandler"
    "layers" : "layersHandler"
        
  defaultHandler: (args) ->
    this.groupingHandler()

  groupingHandler: (args) ->
    window.app.load_grouping_view()

  layersHandler: (args) ->
    window.app.load_layers_view()


window.EditorRouter = EditorRouter