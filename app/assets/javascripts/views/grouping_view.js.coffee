class GroupingView extends Backbone.View
  el: "#app"
  sidebar: "#sidebar"
  iframe: "#iframe"
  
  initialize: ->
    this.render()

  get_iframe_src: ->
    $design = this.model
    "/extracted/#{$design.get('safe_name')}/#{$design.get('safe_name_prefix')}.png"
    

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

    iframe_url = this.get_iframe_src()
    $(this.iframe).attr 'src', iframe_url

window.GroupingView = GroupingView

