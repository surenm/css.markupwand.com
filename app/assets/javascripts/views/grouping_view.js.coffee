#= require './view'

class GroupingView extends View
  el: "#app"
  left_sidebar: "#left-sidebar"
  right_sidebar: "#right-sidebar"
  iframe: "#iframe"

  events: {
    "click #add-new-grouping-box": "add_grouping_box_handler"
  }
  
  initialize: ->
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
        this.main_canvas.drawFilledRectangle child.bounds
      else 
        this.main_canvas.drawFilledRectangle child.bounds, 'rgba(0, 0, 0, 0.1)'
    this.main_canvas.drawBounds grouping_box.bounds, "#0000ff"

  handle_multiple_grouping_box_selection: (grouping_boxes) ->
    this.main_canvas.clear()
    for grouping_box in grouping_boxes
      this.main_canvas.drawBounds grouping_box.bounds, 'rgba(0, 0, 255, 0.3)'

  add_grouping_box_handler: (event) ->
    event.stopPropagation()
    selected_node = $(@tree_element).tree('getSelectedNode')
    
    if not selected_node
      # There is no node that has been selected. Have to get the root node
      root_node_id = root_grouping_box.id
      selected_node = $(@tree_element).tree('getNodeById', root_node_id)
     
    $(@tree_element).tree 'appendNode', { label: 'NEW GROUPING BOX', id: 1 }, selected_node




window.GroupingView = GroupingView

