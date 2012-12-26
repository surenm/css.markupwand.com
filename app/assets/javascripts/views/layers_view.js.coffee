#= require '../lib/bounding_box'

class LayersView extends Backbone.View
  el: "#app"
  sidebar: "#right-sidebar"
  top_bar: "#top-bar"
  editor: "#editor"

  initialize: ->
    text_area = $(this.sidebar).find('textarea')[0]
    editor = CodeMirror.fromTextArea text_area, {
      lineNumbers: true,
      theme: 'ambiance',
      mode: 'css'
    }

    editor.setSize 350, 300
    editor.defaultTextheight 16

window.LayersView = LayersView