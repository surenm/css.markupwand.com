class ImagesView extends Backbone.View
  el: "#content"

  initialize: () ->
    $(this.el).html $("#images-view-template").html()

window.ImagesView = ImagesView