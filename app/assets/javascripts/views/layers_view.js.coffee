#= require '../lib/bounding_box'

class LayersView extends Backbone.View
  el: "#app"
  sidebar: "#sidebar"
  topbar: "#topbar"
  editor: "#editor"

  events: 
    "layer-selected.editor #editor": "editor_click_handler"

  initialize: ->
    sidebar_template = $("#layers-sidebar-template").html()
    $(this.sidebar).html(sidebar_template)

    topbar_template = $("#layers-topbar-template").html()
    $(this.topbar).html(topbar_template)

    @text_area = $(this.sidebar).find('textarea')[0]
    @code_editor = CodeMirror.fromTextArea @text_area, {
      lineNumbers: false
      theme: 'ambiance'
      mode: 'css'
      textWrapping: true
      width: 380
    }

  editor_click_handler: (event) ->
    layer = event.layer
    style_rules = layer.get('style_rules').join ';\n'
    if style_rules != ''
      style_rules += ';\n'
      
    @code_editor.setValue style_rules


window.LayersView = LayersView