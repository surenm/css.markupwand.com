class GroupingView extends Backbone.View
  el: "#app"
  sidebar: "#sidebar"
  iframe: "#iframe"
  
  initialize: () ->
    this.render()

  render: () ->
    $design = window.app.design

    $(this.sidebar).tree
      data: [root_grouping_box]
      autoOpen: 0
      dragAndDrop: true
      selectable: true
      autoEscape: false

    $(this.sidebar).bind 'tree.click', (event) ->
      node = event.node


window.GroupingView = GroupingView

