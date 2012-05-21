window.updateSelected = (tag, xpath)->
  if window.Goyaka['multiSelectEnabled']
    $('.group-tags-block').html($('.group-tags-block').html() + ' hello ')
  else
    $('#tag-switcher').val(tag)
    $('#item-xpath').html(xpath)
    
window.Goyaka = {}

window.Goyaka['multiSelectEnabled'] = false  
window.enableMultiSelect = ->
  if $('.multiselect').css('visibility') == 'hidden'
    $('.multiselect').css('visibility','visible')
    $('.edit-tags').hide()
    $('.grouptags').show()
    window.Goyaka['multiSelectEnabled'] = true
    $('.group-tags-block').html('')
  else
    $('.edit-tags').show()
    $('.grouptags').hide()
    $('.multiselect').css('visibility','hidden')
    window.Goyaka['multiSelectEnabled'] = false

class Editor
  constructor: (target) ->
    @iframe_dom = $(target).contents()
    
    this.add_editor_stylesheet()
    # Binding to highlight a div when hovered
    @iframe_dom.find("div,p").mouseenter {dom: this}, mouseEnterHandler
    @iframe_dom.find("div,p").mouseleave {dom: this}, mouseLeaveHandler
  
  reset_highlight: (target) ->
    @iframe_dom.find("div,p").removeClass "editor-highlight"
  add_editor_stylesheet: () ->
    cssLink = document.createElement("link")

    cssLink.href = "./assets/iframe.css"
    cssLink.rel  = "stylesheet"
    cssLink.type = "text/css"

    $(@iframe_dom).find('body').append(cssLink)
  
  get_grid_id = (obj) ->
    grid_id = $(obj).data('gridId')
    return grid_id
    
  mouseEnterHandler = (event) ->
    event.stopPropagation()
    event.data.dom.reset_highlight()
    $(this).addClass "editor-highlight"  
    
  mouseLeaveHandler = (event) ->
    event.stopPropagation()

$(document).ready ->
  $("iframe").load ->
    editor = new Editor "#editor-iframe"

  $(window).keydown (e) ->
    if (navigator.userAgent.indexOf('Mac OS X') != -1) and (e.altKey)
      window.enableMultiSelect()
    else if  (navigator.userAgent.indexOf('Mac OS X') == -1) and (e.ctrlKey)
      # Non-mac browsers. Not tested yet.
      window.enableMultiSelect()
    return true