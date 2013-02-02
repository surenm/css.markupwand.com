class CropView extends Backbone.View
  el: "#content"

  initialize: () ->

  events:
    "click #crop-save" : "crop_save"

  set_dimensions: (img) ->
    new_img = new Image();

    new_img.onload =  ->
      height = new_img.height
      width  = new_img.width
      $("#crop-image-container").css('width', width)
      $("#crop-image-container").css('height', height)
      if $("#crop-modal .modal-body").height() > height
        difference = $("#crop-modal .modal-body").height() - height
        $("#crop-image-container").css('margin-top', difference/2)
      console.log "Image size #{height} #{width}"

    new_img.src = img;


  show: (name, layer_id) ->

    render_data = 
      image_name : name 
      image_src  : '/extracted/' + window.design.id + '/images/' + name
      layer_id   : layer_id

    @set_dimensions(render_data['image_src'])
    @render(render_data)
    $("#crop-image").Jcrop(
      bgColor   : 'black',
      bgOpacity : .4,
      onSelect  : @update_coords
    )

  post_data : ->
    x        : $('#crop-x').val()
    y        : $('#crop-y').val()
    w        : $('#crop-w').val()
    h        : $('#crop-h').val()
    layer_id : $('#crop-layer-id').val()

  update_coords: (c)->
    $('#crop-x').val(c.x);
    $('#crop-y').val(c.y);
    $('#crop-w').val(c.w);
    $('#crop-h').val(c.h);

  show_loading: ->
    $('#crop-loading').html('Cropping..')
    $('#crop-loading').show()
    $('#crop-image-container').hide()

  hide_loading: ->
    $('#crop-loading').hide()
    $('#crop-image-container').hide()

  crop_cb: (data)->
    if data.status == 'SUCCESS'
        src = $('#crop-image').attr('src')
        src = src + '?' + (new Date()).getTime()
        $('#crop-image').attr('src', src)
        $('#crop-image').on('load', ->
          app.layers_view.child_view.crop_view.set_dimensions(src)
        )
        app.layers_view.child_view.crop_view.hide_loading()
    else
      $('#crop-loading').html('Failed!')


  crop_save: (e)->
    @show_loading()
    $.post '/design/' + window.design.id + '/image-crop', @post_data(), @crop_cb

    false

  render: (data) ->
    $('#crop-modal').remove()
    html = _.template $("#crop-view-template").html(), data
    $(this.el).append $(html)
    $('#crop-modal').modal('show')

window.CropView = CropView