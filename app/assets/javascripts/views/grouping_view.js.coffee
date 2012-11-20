#= require './view'

class GroupingView extends View
  el: "#app"
  left_sidebar: "#left-sidebar"
  right_sidebar: "#right-sidebar"
  iframe: "#iframe"
  context_area: "#context-area"

  events: {
    "click #add-new-grouping-box": "add_grouping_box_handler"
    "click #move-grouping-box": "move_grouping_box_handler"
    "click #flip-grouping-box": "flip_grouping_box_handler"
    "click #done": "done_handler"
    "click #cancel": "cancel_handler"
  }
  
  GroupingTypes = 
    NEW_GROUPING_BOX: "new-grouping-box"
    FLIP: "flip"
    MOVE: "move"

  initialize: ->
    @grouping_type = null
    this.render()

  get_iframe_src: ->
    $design = this.model
    "/design/#{$design.get('id')}/grouping"

  render: () ->
    
    $design = this.model
    $this = this

    this.render_iframe()

    template = $("#grouping-left-sidebar-template").html()
    $(this.left_sidebar).html(template)

    this.reset_right_sidebar()

    @tree_element = $(this.left_sidebar).find('#grouping-tree')
    
    $(@tree_element).tree
      data: [root_grouping_box]
      autoOpen: 0
      dragAndDrop: true
      selectable: true
      autoEscape: false

    $(@tree_element).bind 'tree.click', (event) ->
      grouping_box = event.node
      
      $this.handle_grouping_box_selection grouping_box

    $(@tree_element).bind 'tree.multiclick', (event) ->
      grouping_boxes = event.nodes
      $this.handle_multiple_grouping_box_selection grouping_boxes

  handle_grouping_box_selection: (grouping_box) ->
    this.main_canvas.clear()
    for child in grouping_box.children
      if child.layers.length > 0
        this.main_canvas.drawFilledRectangle child.bounds, 'rgba(0, 0, 255, 0.2)'
      else 
        this.main_canvas.drawFilledRectangle child.bounds, 'rgba(0, 0, 255, 0.1)'
    this.main_canvas.drawBounds grouping_box.bounds, "#0000ff"

  handle_multiple_grouping_box_selection: (grouping_boxes) ->
    this.main_canvas.clear()
    bounding_boxes = []
    for grouping_box in grouping_boxes
      this.main_canvas.drawFilledRectangle grouping_box.bounds, 'rgba(0, 0, 255, 0.1)'
      bounding_boxes.push grouping_box.bounds

    super_bounds = BoundingBox.getSuperBounds bounding_boxes
    this.main_canvas.drawBounds super_bounds, '#ff0000'

  reset_right_sidebar: ->
    @grouping_type = null
    template = $("#right-sidebar-template").html()
    $(this.right_sidebar).html(template)

  add_grouping_box_handler: (event) ->
    event.stopPropagation()
    @grouping_type = GroupingTypes.NEW_GROUPING_BOX
    $(@tree_element).tree('enableMultiSelectMode')

    template = $("#grouping-context-area-template").html()
    $(this.context_area).html(template)


  move_grouping_box_handler: (event) ->
    event.stopPropagation()

  flip_grouping_box_handler: (event) ->
    event.stopPropagation()

  done_handler: (event) ->
    event.stopPropagation()
    
    switch @grouping_type
      when GroupingTypes.NEW_GROUPING_BOX
        selected_nodes = $(@tree_element).tree('getSelectedNodes')
        selected_bounding_boxes = (node.bounds for node in selected_nodes)

        super_bounds = BoundingBox.getSuperBounds selected_bounding_boxes
        name = BoundingBox.toString super_bounds

        if selected_nodes.length == 0
          return

        first_node = selected_nodes[0]
        layer_keys = []
        for node in selected_nodes
          layer_keys = layer_keys.concat node.layers

        parent = first_node.parent
        orientation = parent.orientation
        
        new_node_data = {
          name: name
          label: name
          bounds: super_bounds,
          orientation: orientation
          layers: layer_keys,
          children: []
        }

        new_node = $(@tree_element).tree 'addNodeAfter', new_node_data, first_node
        
        for node in selected_nodes
          $(@tree_element).tree('moveNode', node, new_node, 'inside')

        $(@tree_element).tree('disableMultiSelectMode')
      else
        console.log "unhandled grouping type"

    @reset_right_sidebar()

  cancel_handler: (event) ->
    event.stopPropagation()

    switch @grouping_type
      when GroupingTypes.NEW_GROUPING_BOX
        $(@tree_element).tree('disableMultiSelectMode')      
      else 
        console.log "unhandled grouping type"

    @reset_right_sidebar()

window.GroupingView = GroupingView