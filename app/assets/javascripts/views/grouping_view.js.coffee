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
    $(this.sidebar).tree
      data: [root_grouping_box]
      autoOpen: 0
      dragAndDrop: true
      selectable: true
      autoEscape: false

    $(this.sidebar).bind 'tree.click', (event) ->
      node = event.node

    this.render_iframe()

window.GroupingView = GroupingView

