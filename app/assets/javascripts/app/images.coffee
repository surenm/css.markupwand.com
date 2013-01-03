$(window).load ->
  $('.layer-name input').blur (e)->
    layer_id           = $(e.target).data('original-id')
    original_name      = $(e.target).data('original-image-name') + ""
    layer_name         = ($(e.target).val())
    authenticity_token = $('[name="authenticity_token"]').val();

    if layer_name != original_name
      url = '/design/' + window.design_name + '/image-rename'
      data =
        uid : layer_id
        image_name : layer_name
        authenticity_token : authenticity_token

      $.post url, data, (resp)->
        console.log resp
    else
      console.log "Nothing changed"

  $('.layer-name input')[0].focus()