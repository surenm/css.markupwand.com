class EditorViewEvents
  # Event handlers for various events on the canvas
  @click_handler: (canvas_layer) ->
    shift_key_pressed = canvas_layer.event.shiftKey
    $editor_view = app.editor_view
    $editor_view.events_canvas.clear()

    if not shift_key_pressed
      # single layer select mode
      $editor_view.reset_selected_layers()
      
    layer = $editor_view.get_object_from_name canvas_layer.name
    $editor_view.add_to_selected_layers layer

    bounding_boxes = []
    
    if shift_key_pressed
      for layer in $editor_view.get_selected_layers()
        bounding_boxes.push layer.get('bounds')
        $editor_view.events_canvas.draw_bounds layer.get('bounds'), Color.LIGHTER_BLUE

      super_bounds = BoundingBox.getSuperBounds bounding_boxes
      $editor_view.events_canvas.draw_selection super_bounds, Color.BLUE
    else
      layers = $editor_view.get_selected_layers()
      $editor_view.events_canvas.draw_selection layers[0].get('bounds'), Color.BLUE    
    
  @mouse_over_handler: (canvas_layer) ->
    $editor_view = app.editor_view
    layer = $editor_view.get_object_from_name canvas_layer.name
    $editor_view.animate_canvas.draw_selection layer.get('bounds'), Color.LIGHTER_ORANGE
    
  @mouse_out_handler: (canvas_layer) ->
    $editor_view = app.editor_view
    $editor_view.animate_canvas.clear()

  @double_click_handler: (canvas_layer) ->

  @dummy_handler: (canvas_layer) ->

window.EditorViewEvents = EditorViewEvents