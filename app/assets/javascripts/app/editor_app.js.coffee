#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class EditorApp
  el: "#editor"

  constructor: () ->
    @design = window.design

  init_editor_area: (editor_el) ->
    @editor_area = new EditorArea(editor_el)

  show_notification: (message)->
    notif = $("#editor-notifications")
    notif.html(message)
    notif.show()

  hide_notification: (message)->
    notif = $("#editor-notifications")
    if message == undefined
      notif.hide()
    else
      notif.html(message)
      setTimeout((->notif.hide()), 1000)

  load_intersection_view: ->
    @intersecting_pairs = new IntersectingPairsCollection()
    @intersecting_pairs.attr('design_id', @design.id)
    $app = this
    @intersecting_pairs.fetch({ 
      success: ()->
        @intersection_view = new IntersectionView({model: $app.intersecting_pairs})
      })
    return
    
  load_grouping_view: ->
    @grouping_view = new GroupingView({model: @design})

  load_layers_view: ->
    @layers_view = new LayersView({model: @design})
    
$(window).load ->

  # design_data and sif_data are defined in import.html.erb
  window.design = new DesignModel(design_data)

  # initiate editor app
  window.app = new EditorApp()

  # Initiate router 
  window.router = new EditorRouter

  Backbone.history.start()