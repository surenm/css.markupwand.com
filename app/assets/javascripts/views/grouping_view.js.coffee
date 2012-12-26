#= require '../lib/bounding_box'

class GroupingView extends Backbone.View
  el: "#app"
  sidebar: "#right-sidebar"
  top_bar: "#top-bar"
  editor: "#editor"

  events: {
    "click #group-layers": "group_layers_handler"
    "click.editor #editor": "editor_click_handler"
  }
  
  GroupingTypes = 
    NEW_GROUPING_BOX: "new-grouping-box"
    FLIP: "flip"
    MOVE: "move"

  initialize: ->
    @grouping_type = null
    @editor_area = window.app.editor_area
    @design = window.design

    this.render()

    $view = this
    this.model.bind 'change', () ->
      $.blockUI({message: "Reloading design"})
      $view.render()
      $.unblockUI()

  get_iframe_src: ->
    $design = this.model
    "/design/#{$design.get('id')}/grouping"

  render: () ->
    
    $design = this.model
    $this = this

    sidebar_template = $("#grouping-left-sidebar-template").html()
    $(this.sidebar).html(sidebar_template)

    top_bar_template = $("#grouping-top-bar-template").html()
    $(this.top_bar).html(top_bar_template)

    @tree_element = $(this.sidebar).find('#grouping-tree')
    $(@tree_element).unbind()

    $(@tree_element).tree
      data: [@design.get('sif').root_grouping_box]
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
    @editor_area.events_canvas.clear()
    @editor_area.events_canvas.draw_bounds grouping_box.bounds

  handle_multiple_grouping_box_selection: (grouping_boxes) ->
    @editor_area.clear()
    bounding_boxes = []
    for grouping_box in grouping_boxes
      @editor_area.events_canvas.draw_filled_rectangle grouping_box.bounds
      bounding_boxes.push grouping_box.bounds

    super_bounds = BoundingBox.getSuperBounds bounding_boxes
    @editor_area.events_canvas.draw_bounds super_bounds

  group_layers_handler: (event) ->
    layer_ids = (layer.get('id') for layer in @editor_area.get_selected_layers())
    $design = @design

    $.blockUI({message: "Grouping boxes..."})
    $.post "/design/#{@design.get('id')}/group-layers", {layers: layer_ids}, (data) ->
      $design.fetch()
      $.unblockUI()

  editor_click_handler: (event) ->
    if @editor_area.get_selected_layers().length > 1
      $("#group-layers").removeClass 'disabled'
    else
      $("#group-layers").addClass 'disabled'

window.GroupingView = GroupingView