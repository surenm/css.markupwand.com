class LayersView extends Backbone.View
  el: "#app"
  content: "#content"
  topbar: "#topbar"
  sidebar: "#sidebar"
  editor: "#editor"
  
  initialize: ->
    @design = window.design

    # populate the app html
    $(this.el).html $("#layers-view-template").html()

    if not @design.is_ready()
      $(this.content).html $("#loading-template").html()

  change_child_view: (view) ->
    if not @design.is_ready()
      return

    $(this.topbar).find("a[href='##{view}']").tab('show')

    if @child_view?
      @child_view.remove()
      $("<div id='content'>").insertAfter $(this.topbar)

    # disable the images timeout
    $.doTimeout 'images'

    if view == 'styles'
      @child_view = new StylesView()
    else if view == 'images'
      @child_view = new ImagesView()
    else if view == 'fonts'
      @child_view = new FontsView()

window.LayersView = LayersView