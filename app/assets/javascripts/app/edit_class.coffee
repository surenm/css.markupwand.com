showAccordion = (node)->
  $(node).parent().prev().find('.accordion-body').collapse('hide')
  $(node).collapse('show')

addAccordionListeners =->
  $('#class-edit-accordion input').focus( ->
    $($("#editor-iframe").contents()).find('body').find('.' + $(this).data('original')).css('border', '1px solid red')
    showAccordion($(this).parent().attr('href'))
  )

$(document).ready ->
  addAccordionListeners()
