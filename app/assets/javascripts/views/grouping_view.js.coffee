#= require '../lib/bounding_box'

class GroupingView extends Backbone.View
  el: "#app"
  left_sidebar: "#left-sidebar"
  context_area: "#context-area"
  action_panel: "#action-panel"

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
    @editor_canvas = window.app.editor_canvas
    this.render()

  get_iframe_src: ->
    $design = this.model
    "/design/#{$design.get('id')}/grouping"

  render: () ->
    
    $design = this.model
    $this = this

    template = $("#grouping-left-sidebar-template").html()
    $(this.left_sidebar).html(template)

    this.reset_context_area()

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
    if grouping_box.has_alternate_grouping
      $("#flip-grouping-box").removeClass 'disabled'
    else
      $("#flip-grouping-box").addClass 'disabled'
    @editor_canvas.clear()
    @editor_canvas.draw_bounds grouping_box.bounds

  handle_multiple_grouping_box_selection: (grouping_boxes) ->
    @editor_canvas.clear()
    bounding_boxes = []
    for grouping_box in grouping_boxes
      @editor_canvas.draw_filled_rectangle grouping_box.bounds
      bounding_boxes.push grouping_box.bounds

    super_bounds = BoundingBox.getSuperBounds bounding_boxes
    @editor_canvas.draw_bounds super_bounds

  reset_context_area: ->
    @grouping_type = null
    $(this.context_area).html("")

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
    $design = this.model
    selected_node = $(@tree_element).tree('getSelectedNode')
    $.post "/design/#{$design.get('id')}/flip", {node: selected_node.name}, (data) ->
      window.location.reload()

  done_handler: (event) ->
    event.stopPropagation()
    
    switch @grouping_type
      when GroupingTypes.NEW_GROUPING_BOX
        selected_nodes = $(@tree_element).tree('getSelectedNodes')
        
        serialized_nodes = (node.bounds for node in selected_nodes)

        $design = this.model
        $.post "/design/#{$design.get('id')}/merge", {nodes: serialized_nodes}, (data) ->
          window.location.reload()
      else
        console.log "unhandled grouping type"

    this.reset_context_area()

  cancel_handler: (event) ->
    event.stopPropagation()

    switch @grouping_type
      when GroupingTypes.NEW_GROUPING_BOX
        @editor_canvas.clear()
        $(@tree_element).tree('disableMultiSelectMode')      
      else 
        console.log "unhandled grouping type"

    this.reset_context_area()

window.GroupingView = GroupingView