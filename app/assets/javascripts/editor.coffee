window.updateSelected = (tag, xpath)->
  $('#tag-switcher').val(tag)
  $('#item-xpath').html(xpath)