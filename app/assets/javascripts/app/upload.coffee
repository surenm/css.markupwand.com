$(document).ready ->
  
  $("#drop-div").fileupload(  
    url: '/designs/upload'
    dataType: 'json'
    acceptFileTypes: /(\.|\/)(psd)$/i
    add: (event, data) ->
      $("#progressbar").show()
      $("#progressbar").progressbar(
        value: 0
      )
      data.submit()
    progress: (event, data) ->
      progress = parseInt(data.loaded/data.total*100, 10)
      console.log progress
      $("#progressbar").progressbar(
        value: progress
      )
    
    done: (event, data) ->
      $("#progressbar").hide()
  )
    