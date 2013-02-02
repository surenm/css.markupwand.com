class CropView extends Backbone.View
  el: "#content"

  initialize: () ->

  events:
    "click #crop-save"         : "crop_save"
    "click #reset-to-original" : "reset_original" 

  set_dimensions: (img) ->
    new_img = new Image();

    new_img.onload =  ->
      height = new_img.height
      width  = new_img.width
      $("#crop-image-container").css('width', width)
      $("#crop-image-container").css('height', height) 
      $("#crop-image").css('width', width)
      $("#crop-image").css('height', height) 

      if height < 400
        difference = 400 - height
        $("#crop-image-container").css('margin-top', difference/2)

    new_img.src = img

  initiate_crop: ->
    $('.jcrop-holder').remove()
    $crop_view = app.layers_view.child_view.crop_view;
    $crop_view.jcrop_api = null 
    $("#crop-image").Jcrop(
      bgColor   : 'black',
      bgOpacity : .4,
      onChange  : $crop_view.update_coords,
      onSelect  : $crop_view.update_coords, ->
        $crop_view.jcrop_api = this
    )

  show: (name, layer_id) ->
    render_data = 
      image_name : name 
      image_src  : '/extracted/' + window.design.id + '/images/' + name
      layer_id   : layer_id

    @current_layer = layer_id
    @set_dimensions(render_data['image_src'])
    @render(render_data)
    @initiate_crop()

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

  show_loading: (text)->
    $('#crop-loading').html(text)
    $('#crop-loading').show()
    $('#crop-image-container').hide()

  hide_loading: ->
    $('#crop-loading').hide()
    $('#crop-image-container').show()

  crop_cb: (data)->
    if data.status == 'SUCCESS'
      $crop_view = app.layers_view.child_view.crop_view 
      src = $('#crop-image').attr('src')
      src = src + '?' + (new Date()).getTime()
      $('#crop-image').attr('src', src)
      $('*[data-layer="' + $crop_view.current_layer + '"] .preview-thumbnail').css('background-image',"url('" + src + "')")

      $('#crop-image').on('load', ->
        app.layers_view.child_view.crop_view.set_dimensions(src)
      )
      $crop_view.jcrop_api.destroy()
      $('#crop-image').css('visibility','visible')
      $crop_view.hide_loading()

      setTimeout($crop_view.initiate_crop, 1000)
    else
      $('#crop-loading').html('Failed!')

  crop_save: (e)->
    @show_loading('Cropping..')
    $.post '/design/' + window.design.id + '/image-crop', @post_data(), @crop_cb
    false

  reset_original: ->
    $.post '/design/' + window.design.id + '/image-reset', @post_data(), @crop_cb
    @show_loading('Cropping..')
    false
    

  render: (data) ->
    $('#crop-modal').remove()
    html = _.template $("#crop-view-template").html(), data
    $(this.el).append $(html)
    $('#crop-modal').modal('show')

window.CropView = CropView