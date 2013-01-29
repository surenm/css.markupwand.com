class ImagesView extends Backbone.View
  el: "#content"

  events: 
    "change input": "layer_name_changed_handler"

  initialize: () ->
    this.render()

  render: () ->
    $(this.el).html $("#images-view-template").html()

  layer_name_changed_handler: (event) ->
    input_el = event.target
    layer_uid = $(input_el).data('layer-id')
    original_name = $(input_el).data('original-image-name')
    new_name = $(input_el).val()

    if original_name != new_name
      post_data =
        uid : layer_uid
        image_name : new_name

      $.post window.design.get_images_rename_url(), post_data, (data)->
        console.log data
        
    else
      console.log "Nothing changed"


window.ImagesView = ImagesView