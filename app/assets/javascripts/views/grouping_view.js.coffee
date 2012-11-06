class GroupingView extends Backbone.View
  el: "#grouping-panel"

  initialize: () ->
    this.render()

  render: () ->
    $design = window.app.design
    console.log [root_grouping_box]

    $(this.el).tree
      data: [root_grouping_box]
      autoOpen: 0
      dragAndDrop: true
      selectable: true
      autoEscape: false

    $(this.el).bind 'tree.click', (event) ->
      node = event.node

    console.log $(this.el)

window.GroupingView = GroupingView

