class StylesView extends Backbone.View
  el: "#content"
  sidebar: "#sidebar"
  editor: "#editor"

  events: 
    "layer-selected.editor #editor": "editor_click_handler"

  initialize: ->
    # instantiate the editor area
    window.app.init_editor_area this.editor

    # Populate side bar view with codemirror editor
    @text_area = $(this.sidebar).find('textarea')[0]
    @code_editor = CodeMirror.fromTextArea @text_area, {
      lineNumbers: true
      theme: 'ambiance'
      mode: 'css'
      textWrapping: true
      width: 380
    }

    # Implement copy to clipboard using zeroclipboard
    $clip = new ZeroClipboard $("#copy-to-clipboard"), {
      moviePath: "/assets/lib/ZeroClipboard.swf"
    }

    $clip.on "complete", (client, args) ->
      # show a notification saying copied to clipboard
      console.log "Successfully copied to clip board"

    # Update clipboard text if code_editor changes
    $code_editor = @code_editor
    $code_editor.on "change", (instance, changeObj) ->
      $clip.setText $code_editor.getValue()

  editor_click_handler: (event) ->
    layer = event.layer
    style_rules = layer.get('style_rules').join ';\n'
    if style_rules != ''
      style_rules += ';\n'
      
    @code_editor.setValue style_rules

window.StylesView = StylesView