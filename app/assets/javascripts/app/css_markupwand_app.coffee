#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views

class App
  el: "#app"

  constructor: () ->
    @design = window.design
    @layers_view = new LayersView({model: @design})

  init_editor_area: (editor_el) ->
    @editor_area = new EditorArea(editor_el)

  change_view: (view) ->
    @layers_view.change_child_view(view)

class AppRouter extends Backbone.Router
  routes:
    "" : "default_handler"
    "styles": "styles_handler"
    "images": "images_handler"
    "fonts": "fonts_handler"
        
  default_handler: (args) ->
    this.styles_handler()
    
  styles_handler: (args) ->
    window.app.change_view('styles')

  images_handler: (args) ->
    window.app.change_view('images')

  fonts_handler: (args) ->
    window.app.change_view('fonts')

$(window).load ->
  # design_data and sif_data are defined in import.html.erb
  window.design = new DesignModel(design_data)

  # initiate editor app
  window.app = new App()

  # Initiate router 
  window.router = new AppRouter()

  Backbone.history.start()