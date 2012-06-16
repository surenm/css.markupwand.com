$(document).ready ->
  apiKey = "ZOFGmR9AQeWSYvsehp6W"
  filepicker.setKey apiKey

  file_url_field = $("#file-upload-form input[name='design[file_url]']")
  file_name_field = $("#file-upload-form input[name='design[name]']")
  form_submit_button = $("#file-upload-submit")

  $("#file-select-zone").click -> 
    filepicker.getFile '*/*', {'multiple': false, 'modal': true}, (url, data) ->
      file_url_field.attr "value", url
      file_name_field.attr "value", data.filename
      form_submit_button.removeAttr "disabled"
    return
  return
  
