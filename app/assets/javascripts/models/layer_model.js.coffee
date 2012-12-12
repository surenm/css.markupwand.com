class LayerModel extends Backbone.Model
  initialize: ->

  to_canvas_data: (canvas_element) ->
    switch this.get('type')
      when 'text'
        return this.text_canvas_data()
      when 'shape'
        return this.shape_canvas_data(canvas_element)
      when 'normal'
        return this.normal_canvas_data()

  text_canvas_data: ->
    text_content = this.get('text').full_text
    bounds = this.get('bounds')

    font = this.get_font_style_string(this.get('text'))
    color = this.get('text').chunks[0].styles.color

    canvas_data =
      name: this.get('uid')
      text: text_content
      bounds: bounds
      width: bounds.right - bounds.left
      height: bounds.bottom - bounds.top
      font: font
      fillStyle: color

    return canvas_data

  normal_canvas_data: ->
    assets_path = window.app.design.get_assets_root()
    image_name = this.get('image_name')
    image_src = $("##{this.get('uid')}")[0]
    bounds = this.get('bounds')

    canvas_data =
      name: this.get('uid')
      src: image_src
      bounds: bounds

    return canvas_data

  shape_canvas_data: (canvas_element) ->
    bounds = this.get('bounds')
    shape = this.get('shape')
    styles = this.get('styles')

    curvature = 0
    
    strokeStyle = null
    strokeWidth = null 

    if shape.curvature?
      curvature = Helper.get_value_from_pixel_string shape.curvature
      strokeStyle = '#fff'
      strokeWidth = 0
      
    if styles.border?
      strokeStyle = styles.border.color
      strokeWidth = Helper.get_value_from_pixel_string styles.border.width

    fillStyle = this.getShapeFillStyle(canvas_element)
    

    canvas_data = 
      name: this.get('uid')
      bounds: bounds
      width: bounds.right - bounds.left
      height: bounds.bottom - bounds.top
      fillStyle: fillStyle
      strokeStyle: strokeStyle
      strokeWidth: strokeWidth
      cornerRadius: curvature

  get_font_style_string: (text_object) ->
    # just render the first style
    text_chunk = text_object.chunks[0]
    styles = text_chunk.styles
    style_string = ""
    
    if styles['font-weight']? and styles['font-weight'] == 'bold'
      style_string += "bold "

    if styles['font-size']?
      style_string += "#{styles['font-size']} "

    return style_string

  getShapeFillStyle: (canvas_element) ->
    styles = this.get('styles')

    fillStyle = null
    if styles['solid_overlay']?
      fillStyle = styles['solid_overlay']
    else if styles['gradient_overlay']?
      gradient_args = Helper.get_gradient_fill_style styles['gradient_overlay'], this.get('bounds')
      fillStyle = $(canvas_element).createGradient gradient_args
    else if styles['solid_fill']?
      fillStyle = styles['solid_fill']
    else if styles['gradient_fill']?
      gradient_args = Helper.get_gradient_fill_style styles['gradient_fill'], this.get('bounds')
      fillStyle = $(canvas_element).createGradient gradient_args

    return fillStyle

    


window.LayerModel = LayerModel
