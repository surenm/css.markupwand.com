$(document).ready ->
  apiKey = "ZOFGmR9AQeWSYvsehp6W"
  filepicker.setKey apiKey

  file_url_field = $("#file-upload-form input[name='design[file_url]']")
  file_name_field = $("#file-upload-form input[name='design[name]']")
  form_submit_button = $("#file-upload-submit")
  
  short_filename = (file_name)->
    file_name_splits = file_name.split('.')
    extension = file_name_splits.pop()
    file_name_only = file_name_splits.join('.')
    if file_name_only.length > 20
      new_file_name_only = file_name_only.slice(0, 20) + '..'
      "#{new_file_name_only}.#{extension}"
    else
      file_name

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
  
