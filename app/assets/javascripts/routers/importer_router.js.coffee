class ImporterRouter extends Backbone.Router
  routes:
    ""              : "defaultHandler"
    "classes"       : "editClasses" 
    "tags"          : "editTags"
    "identifiers"   : "editIdentifiers"
    "dom"           : "editDom"
    "grid/:grid_id" : "editGrid"
    "*args"         : "defaultHandler"
    
  editClasses: () ->
    window.app.load_design_sidebar("classes")
      
  editTags: () ->
    window.app.load_design_sidebar("tags")
    
  editIdentifiers: () ->
    window.app.load_design_sidebar("identifiers")
    
  editDom: () ->
    window.app.load_design_sidebar("dom")
    
  defaultHandler: (args) ->
    window.app.load_design_sidebar()

window.EditorRouter = EditorRouter