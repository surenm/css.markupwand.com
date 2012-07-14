$(document).ready ->
  apiKey = "ZOFGmR9AQeWSYvsehp6W"
  filepicker.setKey apiKey

  $(".upload-font-button").click (evt)->
    button = this 
    filepicker.getFile '*/*', {'multiple': false, 'modal': true}, (url, data) ->
      id = $(button).attr('id')
      id = id.replace('-button', '')
      $('#' + id + '-url').val(url)
      $('#' + id + '-upload-name').val(data.filename)
      $('#' + id + '-name').html(data.filename)
      $(button).attr("disabled", "disabled");
    return
  