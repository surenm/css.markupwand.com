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

    filepicker_options = 
      'multiple': false
      'modal': true
      'location': filepicker.SERVICES.COMPUTER
      'services' : [   
        filepicker.SERVICES.COMPUTER
        filepicker.SERVICES.DROPBOX
        filepicker.SERVICES.BOX
        filepicker.SERVICES.GOOGLE_DRIVE
        filepicker.SERVICES.FTP
      ]
  
    success_handler = (url, fpicker_data) ->
      extension = fpicker_data.filename.split('.').pop()
      if extension.toLowerCase() == 'psd'
        $.post "/design/uploaded", {design: {file_url: url, name: fpicker_data.filename}}, (data) ->
          console.log data
      else
        $("#file-type-error-popup").dialog 
          modal: true
          draggable: false
          resizable: false
          buttons: [
            {
              text: 'Ok'
              click: () -> $(this).dialog('close')
              class: 'btn btn-danger'
            }
          ]

        
      return
     
    filepicker.getFile '*/*', filepicker_options, success_handler
  return