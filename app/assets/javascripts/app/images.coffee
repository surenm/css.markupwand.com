$(window).load ->
  $('.layer-name input').blur((e)->
    layer_id   = ($(e.target).data('original-id'))
    layer_name = ($(e.target).val())
    
    url = '/design/' + window.design_name + '/image-rename'
    data =
      uid : layer_id
      image_name : layer_name

    $.post url, data, (resp)->
      debugger
      console.log resp
    )

  $('.layer-name input')[0].focus()