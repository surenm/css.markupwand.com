showAccordion = (node)->
  $(node).parent().prev().find('.accordion-body').collapse('hide')
  $(node).collapse('show')

addAccordionListeners =->
  $('#class-edit-accordion input').focus( ->
    console.log('focussed')
    showAccordion($(this).parent().attr('href'))
  )

$(document).ready ->
  addAccordionListeners()