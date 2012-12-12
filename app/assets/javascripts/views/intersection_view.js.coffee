class IntersectionView extends Backbone.View
  el: "#app"
  left_sidebar: "#left-sidebar"
  right_sidebar: "#right-sidebar"
 
  initialize: ->
    this.render()

  render_no_intersections: ->
    template = $("#no-intersections").html()
    $(this.left_sidebar).html(template)

  render: ->
    @intersecting_pairs = this.model

    if @intersecting_pairs.length == 0
      this.render_no_intersections()
    else
      list_node = $('<ul></ul>')
      for intersecting_pair in @intersecting_pairs.models
        left = intersecting_pair.get('left')
        right = intersecting_pair.get('right')
        node = $('<li></li>')
        right_name = window.design.layers.get(right).get('name')
        left_name = window.design.layers.get(left).get('name')
        node.html "#{right_name}(#{right}) and #{left_name}(#{left})"
        list_node.append(node)
      $(this.left_sidebar).append(list_node)


window.IntersectionView = IntersectionView