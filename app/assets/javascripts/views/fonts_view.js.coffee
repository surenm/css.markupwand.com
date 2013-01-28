class FontsView extends Backbone.View
  el: "#content"

  initialize: () ->
    this.render()

  render: () ->
    $(this.el).html $("#fonts-view-template").html()

window.FontsView = FontsView