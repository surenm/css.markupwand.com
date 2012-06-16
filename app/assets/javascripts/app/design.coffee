$(document).ready ->
  console.log design.status
  if design.status != "completed"
    $.doTimeout 6000, () ->
      # TODO: make this just reload this dom instead of reloading the page
      window.location.reload()
    