$(document).ready ->
  if not design? or design.status != "completed"
    $.doTimeout 10000, () ->
      # TODO: make this just reload this dom instead of reloading the page
      window.location.reload()
    