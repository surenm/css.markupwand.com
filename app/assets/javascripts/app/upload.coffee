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

  $("#upload-design").click ->
    filepicker_services = [
      filepicker.SERVICES.COMPUTER
      filepicker.SERVICES.DROPBOX
      filepicker.SERVICES.BOX
      filepicker.SERVICES.GOOGLE_DRIVE
      filepicker.SERVICES.FTP
    ]
    filepicker.getFile '*/*', {'multiple': false, 'modal': true, extension: '.psd', 'location': filepicker.SERVICES.COMPUTER,  'services' : filepicker_services}, (url, data) ->
      $.post "/design/uploaded", {design: {file_url: url, name: data.filename}}, (success) ->
        console.log success
    return
  return
  
