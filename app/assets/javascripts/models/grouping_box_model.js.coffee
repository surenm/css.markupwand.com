class GroupingBoxModel extends Backbone.Model
  initialize: ->

  to_canvas_data: ->
    bounds = this.get('bounds')

    canvas_data = 
      name: "g_#{this.get('name')}"
      bounds: bounds
      width: bounds.right - bounds.left
      height: bounds.bottom - bounds.top

    return canvas_data

window.GroupingBoxModel = GroupingBoxModel