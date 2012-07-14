$(document).ready ->
  apiKey = "ZOFGmR9AQeWSYvsehp6W"
  filepicker.setKey apiKey

  $("#file-select-zone").click -> 
    filepicker.getFile '*/*', {'multiple': false, 'modal': true}, (url, data) ->
      file_url_field.attr "value", url
      file_name_field.attr "value", data.filename
      form_submit_button.removeAttr "disabled"
      $('.chosen-file').show()
      $('#file-name').html(short_filename(data.filename))
      $('.photo-upload-action').hide()
    return
  return