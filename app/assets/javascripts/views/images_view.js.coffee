class ImagesView extends Backbone.View
  el: "#content"

  initialize: () ->
    this.render()

  render: () ->
    $(this.el).html $("#images-view-template").html()

window.ImagesView = ImagesView