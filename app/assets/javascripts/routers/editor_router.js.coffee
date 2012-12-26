class EditorRouter extends Backbone.Router
  routes:
    "" : "defaultHandler"
    "grouping" : "groupingHandler"
    "intersection" : "intersectionHandler"
    "layers": "layersHandler"
        
  defaultHandler: (args) ->
    this.groupingHandler()

  groupingHandler: (args) ->
    window.app.load_grouping_view()

  intersectionHandler: (args) ->
    window.app.load_intersection_view()

  layersHandler: (args) ->
    window.app.load_layers_view()

window.EditorRouter = EditorRouter