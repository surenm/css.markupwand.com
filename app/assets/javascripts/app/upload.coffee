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
    Analytical.event "file_upload", "attempted"
    filepicker.getFile ['image/photoshop', 'image/x-photoshop', 'image/psd', 'application/photoshop',
                        'application/psd', 'zz-application/zz-winassoc-psd', 'application/x-photoshop',
                        'image/vnd.adobe.photoshop'], {'multiple': false, 'modal': true, 'location': filepicker.SERVICES.DROPBOX,  'services' : [filepicker.SERVICES.COMPUTER, filepicker.SERVICES.DROPBOX]}, (url, data) ->
    
      Analytical.event "file_upload", "selected"
      file_url_field.attr "value", url
      file_name_field.attr "value", data.filename
      form_submit_button.removeAttr "disabled"
      $('.chosen-file').show()
      $('#file-name').html(short_filename(data.filename))
      $('.photo-upload-action').hide()
    return
  return
  
