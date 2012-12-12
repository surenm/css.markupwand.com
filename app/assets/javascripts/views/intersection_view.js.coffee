class IntersectionView extends Backbone.View
  el: "#app"
  left_sidebar: "#left-sidebar"
  intersections_sidebar: "#intersections-sidebar"
  intersections_list: "#intersections-list"
  
  initialize: ->
    this.render()

  render_no_intersections: ->
    template = $("#no-intersections").html()
    $(this.left_sidebar).html(template)

  render_wrapper: ->
    template = $('#intersections-sidebar').html()
    $(this.left_sidebar).html(template)

  render: ->
    @intersecting_pairs = this.model

    if @intersecting_pairs.length == 0
      this.render_no_intersections()
    else
      this.render_wrapper()
      list_node = $(this.intersections_list)

      for intersecting_pair in @intersecting_pairs.models
        left = intersecting_pair.get('left')
        right = intersecting_pair.get('right')
        node = $('<li></li>')
        right_name = window.design.layers.get(right).get('name')
        left_name = window.design.layers.get(left).get('name')
        node.html "#{right_name}(#{right}) and #{left_name}(#{left})"
        list_node.append(node)



window.IntersectionView = IntersectionView