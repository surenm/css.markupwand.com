class ImporterRouter extends Backbone.Router
  routes:
    ""              : "defaultHandler"
    "dom"           : "editDom"
        
  editDom: () ->
    window.app.load_design_sidebar("dom_tree")
    
  defaultHandler: (args) ->
    window.app.load_design_sidebar()

window.ImporterRouter = ImporterRouter