class ImagesView extends Backbone.View
  el: "#content"

  events: 
    "change inputasdfa": "layer_name_changed_handler"
#    "keydown .editable-input input" : "handle_tab"

  initialize: () ->
    $.fn.editable.defaults.mode = 'inline';
    this.render()

  handle_tab: (e) ->
    if (e.keyCode == 9)
      e.preventDefault();
      $(e.target).parent().parent().parent().parent().parent().parent().parent().parent().next().find('.image-name-editable').editable('toggle')
    window.input = $(e.target)


  render: () ->
    $(this.el).html $("#images-view-template").html()    
    $(".image-name-editable").editable()
    $(".image-name-editable").first().editable('toggle')
    $(".image-name-editable").first().parent().find('.editable-input input').focus()


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