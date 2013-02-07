class StylesView extends Backbone.View
  el: "#content"
  sidebar: "#sidebar"
  editor: "#editor"

  events: 
    "layer-selected.editor #editor": "editor_click_handler"
    "click .code-area .nav a": "styles_tab_handler"
    "click #image-tab-btn" : "move_to_image_tab"
    "click #zoom button": "zoom_level_handler"
    "click #measureit": "measure_handler"
    "click #tour": "tour_handler"

  initialize: ->
    @design = window.design

    @design.bind 'change:editor_scaling', () ->
      slider_percentage = Math.round this.get('editor_scaling') * 100
      $("#zoom-slider").slider 'option', 'value', slider_percentage
    
    this.render()

  render: ->
    # populate editor and sidebar
    $(this.el).html $("#styles-view-template").html()

    # instantiate elements top action bar
    $this = this
    $("#zoom-slider").slider
      range: "min"
      min: 40
      max: 250
      value: 100
      step: 10
      slide: (event, slider) ->
        event.slider = slider
        $this.zoom_level_handler(event)

    # instantiate the editor area
    window.app.init_editor_area this.editor
    @editor_area = window.app.editor_area

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

      #Analytical.event('Feature: CSS Clipboard used', {design: window.design.get('id')})

    # Update clipboard text if code_editor changes
    $code_editor = @code_editor
    $code_editor.on "change", (instance, changeObj) ->
      $clip.setText $code_editor.getValue()

  move_to_image_tab: (e)->
    if e.target.nodeName == 'I'
      target = $(e.target).parent()
    else
      target = $(e.target)

    layer_id = target.data('layer-id')
    window.location.hash = 'images'

    setTimeout(->
      $('#imagename-' + layer_id).editable('toggle')
    , 50)

    false

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
    image_src = "#{@design.get_assets_root()}/#{image_name}"
    image_template =  _.template $("#image-template").html()
    html = image_template({image_src: image_src, layer: @selected_layer, design_id : window.design.id})
    $(this.sidebar).find('.image-area').html(html)

  reset_image_area: () ->
    $(this.sidebar).find('.image-area').html("")

  zoom_level_handler: (event) ->
    if event.type == "click"
      zoom_level = $(event.currentTarget).data('zoom-size')
    else if event.type == "slide"
      zoom_level = event.slider.value

    @editor_area.set_zoom zoom_level

  measure_handler: (event) ->
    measureit_button = event.currentTarget

    if $(measureit_button).hasClass 'active'
      $(this.sidebar).animate {opacity: 1}, 'slow'
      $(measureit_button).removeClass 'active btn-info'
      $(this.editor).css 'cursor', 'pointer'
      @editor_area.disable_measureit()
    else
      $(this.sidebar).animate {opacity: 0.2}, 'slow'
      $(measureit_button).addClass 'active btn-info'
      $(this.editor).css 'cursor', 'crosshair'
      @editor_area.enable_measureit()
      #Analytical.event('Feature: Measureit plugin used', {design: window.design.get('id')})

  tour_handler: (event) ->
    tour = new Tour()

    tour.addStep 
      element: "#zoom"
      title: "Zoom in and zoom out"
      content: "Actual size, fit size and somewhere between 50% to 250%"
      placement: 'bottom'
      animation: true

    tour.addStep 
      element: "#measureit"
      title: "Measure "
      content: "Measure height and width in pixels at any zoom level"
      placement: 'bottom'
      animation: true

    tour.start(true)

window.StylesView = StylesView