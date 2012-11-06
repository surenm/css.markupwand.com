class View extends Backbone.View

  inject_editor_elements: () ->
    canvas_elements = ['main-canvas', 'mouseoverlay-canvas', 'ruler-canvas']
    for canvas_element in canvas_elements
      canvas_dom_element = document.createElement 'canvas'
      canvas_dom_element.id = canvas_element
      $(canvas_dom_element).css('position', 'absolute').css('top', '0')
      $(@iframe_dom).find('body').append canvas_dom_element

  init_canvas_objects: () ->
    @main_canvas = new EditorCanvas(this.get_canvas('main-canvas'))
    @mouseoverlay_canvas = new EditorCanvas(this.get_canvas('mouseoverlay-canvas'))

  set_iframe_dom: (iframe_dom) ->
    @iframe_dom = iframe_dom

  get_canvas: (canvas_name) ->
    canvas = $(@iframe_dom).find("##{canvas_name}").first()
    return canvas

  render_iframe: () ->
    $this = this
    
    iframe_url = this.get_iframe_src()
    
    $(this.iframe).load () ->
      $this.set_iframe_dom $(this).contents()
      #$this.inject_editor_elements()
      $this.init_canvas_objects()

    $(this.iframe).attr 'src', iframe_url

window.View = View
