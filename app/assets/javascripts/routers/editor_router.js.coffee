class EditorRouter extends Backbone.Router
  routes:
    "" : "defaultHandler"
    "layers": "layersHandler"
        
  defaultHandler: (args) ->
    this.layersHandler()
    
  layersHandler: (args) ->
    window.app.load_layers_view()

window.EditorRouter = EditorRouter