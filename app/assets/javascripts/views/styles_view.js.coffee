class StylesView extends Backbone.View
  el: "#content"
  sidebar: "#sidebar"
  editor: "#editor"

  events: 
    "layer-selected.editor #editor": "editor_click_handler"
    "click .code-area .nav a": "styles_tab_handler"

  initialize: ->
    this.render()

  render: ->
    # populate editor and sidebar
    $(this.el).html $("#styles-view-template").html()

    # instantiate the editor area
    window.app.init_editor_area this.editor

    # Populate side bar view with codemirror editor
    @language_tabbar = $(this.sidebar).find('.nav')[0]
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
      if args.text == ""
        $("#copy-to-clipboard").html('<i class="icon-ban-circle"> </i>Empty').addClass('btn-link')
      else
        $("#copy-to-clipboard").html('<i class="icon-ok"> </i>Copied').addClass('btn-link')

      $("#copy-to-clipboard").switchClass 'btn-link', 'btn', 1000, 'linear', () ->
        $("#copy-to-clipboard").html('<i class="icon-clipboard"> </i>Copy to clipboard')

    # Update clipboard text if code_editor changes
    $code_editor = @code_editor
    $code_editor.on "change", (instance, changeObj) ->
      $clip.setText $code_editor.getValue()

  editor_click_handler: (event) ->
    @selected_layer = event.layer
    currently_selected_tab = $(".code-area").find(".active").find('a')
    lang = $(currently_selected_tab).data('lang')
    this.show_styles_code(lang)
    this.reset_image_area()

    if @selected_layer.get('type') == 'normal'
      this.show_layer_image()

  styles_tab_handler: (event) ->
    current_tab_element = event.srcElement
    $(current_tab_element).tab('show')

    lang = $(current_tab_element).data('lang')
    this.show_styles_code(lang)
    this.reset_image_area()
    return false

  show_styles_code: (lang) ->
    if not @selected_layer
      return
      
    if lang == 'scss'
      style_rules = @selected_layer.getSCSS()
    else if lang == 'css'
      style_rules = @selected_layer.getCSS()

    @code_editor.setValue style_rules

  show_layer_image: () ->
    image_name = @selected_layer.get('image_name')
    image_src = "#{window.design.get_assets_root()}/#{image_name}"
    image_template =  _.template $("#image-template").html()
    html = image_template({image_src: image_src, layer: @selected_layer})
    $(this.sidebar).find('.image-area').html(html)

  reset_image_area: () ->
    $(this.sidebar).find('.image-area').html("")

window.StylesView = StylesView