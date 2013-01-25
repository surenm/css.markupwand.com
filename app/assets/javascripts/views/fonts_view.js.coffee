class FontsView extends Backbone.View
  el: "#content"

  initialize: () ->
    $(this.el).html $("#fonts-view-template").html()

window.FontsView = FontsView