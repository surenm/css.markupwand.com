class EditorRouter extends Backbone.Router
  routes:
    "" : "defaultHandler"
    "grouping" : "groupingHandler"
    "intersection" : "intersectionHandler"
        
  defaultHandler: (args) ->
    this.groupingHandler()

  groupingHandler: (args) ->
    window.app.load_grouping_view()

  intersectionHandler: (args) ->
    window.app.load_intersection_view()

window.EditorRouter = EditorRouter