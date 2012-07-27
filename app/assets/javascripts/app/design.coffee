update_process_status = ->
  $.doTimeout 10000, () ->
    $.get("/design/#{design_id}.json", (data)->
      if data.status == 'completed'
        $('.status-box').addClass('hide')
        $('.completed-box').removeClass('hide')
      else
        update_process_status()
      )

$(document).ready ->
  if not design? or design.status != "completed"
    update_process_status()