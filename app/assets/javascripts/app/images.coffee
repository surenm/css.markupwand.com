$(window).load ->
  $('.layer-name input').blur((e)->
    console.log($(e.target).val())
    )