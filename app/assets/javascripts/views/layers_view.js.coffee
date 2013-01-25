class LayersView extends Backbone.View
  el: "#app"
  topbar: "#topbar"
  sidebar: "#sidebar"
  editor: "#editor"
  
  initialize: ->
    # populate the app html
    app_html = $("#layers-view-template").html()
    $(this.el).html app_html

  change_child_view: (view) ->  
    $(this.topbar).find("a[href='##{view}']").tab('show')

    if @child_view?
      @child_view.stopListening()

    if view == 'styles'
      @child_view = new StylesView()
    else if view == 'images'
      @child_view = new ImagesView()
    else if view == 'fonts'
      @child_view = new FontsView()

window.LayersView = LayersView