class EditorRouter extends Backbone.Router
  routes:
    "" : "defaultHandler"
    "grouping" : "groupingHandler"
        
  defaultHandler: (args) ->
    this.groupingHandler()

  groupingHandler: (args) ->
    window.app.load_grouping_view()

window.EditorRouter = EditorRouter