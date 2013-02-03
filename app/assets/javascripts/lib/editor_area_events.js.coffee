class EditorAreaEvents

  # Event handlers for various events on the canvas
  @click_handler: (canvas_layer) ->
    shift_key_pressed = canvas_layer.event.shiftKey
    $editor_area = app.editor_area
    $editor_area.events_canvas.clear()

    if not shift_key_pressed
      # single layer select mode
      $editor_area.reset_selected_layers()
      
    layer = $editor_area.get_object_from_name canvas_layer.name
    $editor_area.add_to_selected_layers layer

    bounding_boxes = []
    
    if shift_key_pressed
      for layer in $editor_area.get_selected_layers()
        bounding_boxes.push layer.get('bounds')
        $editor_area.events_canvas.draw_bounds layer.get('bounds'), Color.LIGHTER_BLUE

      super_bounds = BoundingBox.getSuperBounds bounding_boxes
      $editor_area.events_canvas.draw_selection super_bounds, Color.BLUE
    else
      layers = $editor_area.get_selected_layers()
      if layers.length > 0
        $editor_area.events_canvas.draw_selection layers[0].get('bounds'), Color.BLUE

    event_data = 
      layer: layer
    event = $.Event 'layer-selected.editor', event_data
    
    $("#editor").trigger(event)

  @double_click_handler: (canvas_layer) ->
    $editor_area = app.editor_area
    layer = $editor_area.get_object_from_name canvas_layer.name
    event = $.Event('double_click.editor')
    event.data =
      layer: layer
    $("#editor").trigger(event)
  
  @mouse_over_handler: (canvas_layer) ->
    $editor_area = app.editor_area
    layer = $editor_area.get_object_from_name canvas_layer.name
    $editor_area.animate_canvas.draw_selection layer.get('bounds'), Color.LIGHTER_ORANGE
    
  @mouse_out_handler: (canvas_layer) ->
    $editor_area = app.editor_area
    $editor_area.animate_canvas.clear()

  @dummy_handler: (canvas_layer) ->

  @area_select_mouse_down_handler: (canvas_layer) ->
    app.editor_area.set_area_select_start {x: canvas_layer.eventX, y: canvas_layer.eventY}

  @area_select_mouse_up_handler: (canvas_layer) ->
    app.editor_area.set_area_select_end {x: canvas_layer.eventX, y: canvas_layer.eventY}

  @area_select_mouse_move_handler: (canvas_layer) ->
    app.editor_area.set_area_select_change {x: canvas_layer.eventX, y: canvas_layer.eventY}

window.EditorAreaEvents = EditorAreaEvents