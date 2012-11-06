#= require './view'

class GroupingView extends View
  el: "#app"
  sidebar: "#sidebar"
  iframe: "#iframe"
  
  initialize: ->
    this.render()

  get_iframe_src: ->
    $design = this.model
    "/design/#{$design.get('id')}/grouping"

  render: () ->
    
    $design = this.model
    $this = this

    this.render_iframe()

    $(this.sidebar).tree
      data: [root_grouping_box]
      autoOpen: 0
      dragAndDrop: true
      selectable: true
      autoEscape: false

    $(this.sidebar).bind 'tree.click', (event) ->
      grouping_box = event.node
      $this.handle_grouping_box_selection grouping_box

  handle_grouping_box_selection: (grouping_box) ->
    this.main_canvas.clear()
    for child in grouping_box.children
      if child.layers.length > 0
        this.main_canvas.drawFilledRectangle child.bounds
      else 
        this.main_canvas.drawFilledRectangle child.bounds, 'rgba(0, 0, 0, 0.1)'
    this.main_canvas.drawBounds grouping_box.bounds, "#0000ff"


window.GroupingView = GroupingView

