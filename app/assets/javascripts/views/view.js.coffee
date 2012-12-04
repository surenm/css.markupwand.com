#= require '../lib/bounding_box'

class View extends Backbone.View

  init_canvas_objects: () ->
    @main_canvas = new EditorCanvas(this.get_canvas_from_iframe('main-canvas'))
    @mouseoverlay_canvas = new EditorCanvas(this.get_canvas_from_iframe('mouseoverlay-canvas'))

  set_iframe_dom: (iframe_dom) ->
    @iframe_dom = iframe_dom

  get_canvas_from_iframe: (canvas_name) ->
    canvas = $(@iframe_dom).find("##{canvas_name}").first()
    return canvas

  get_canvas: (canvas_name) ->
    canvas = $("##{canvas_name}").first()

  render_iframe: () ->
    $this = this
    
    iframe_url = this.get_iframe_src()
    
    $(this.iframe).load () ->
      $this.set_iframe_dom $(this).contents()
      $this.init_canvas_objects()

    $(this.iframe).attr 'src', iframe_url

window.View = View
