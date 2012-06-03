$(document).ready ->
  
  $("#drop-div").fileupload(  
    url: '/designs/upload'
    dataType: 'json'
    acceptFileTypes: /(\.|\/)(psd)$/i
    add: (event, data) ->
      allow_upload = true
      $.each(data.files, (index, file) ->
        if file.type != "image/vnd.adobe.photoshop"
          allow_upload = false
      );
      
      if allow_upload
        $("#progressbar").show()
        $("#progressbar").progressbar(
          value: 0
        )
        data.submit()
      else 
        alert "Only Photoshop files allowed"
  
    progress: (event, data) ->
      progress = parseInt(data.loaded/data.total*100, 10)
      console.log progress
      $("#progressbar").progressbar(
        value: progress
      )
    
    done: (event, data) ->
      $("#progressbar").hide()
  )
    