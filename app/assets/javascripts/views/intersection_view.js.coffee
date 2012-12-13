class IntersectionView extends Backbone.View
  el: "#app"
  left_sidebar: "#left-sidebar"
  intersections_sidebar: "#intersections-sidebar"
  intersections_list: "#intersections-list"
  
  initialize: ->
    this.render()
    @editor_canvas = window.app.editor_canvas
    @design_canvas = @editor_canvas.design_canvas
    @design        = window.design
    $("#animate-canvas").css("display", "none")

  events:
    "click .top-head-item": "focus_intersection_item"
    "click .remove-layer" : "delete_layer"
    "click .layer-item"   : "focus_deletable_item"

  collapse_all: ->
    $('.intersection-item .actions').hide()

  focus_deletable_item: (e)->
    layer_uid = $(e.target).parent().data('layer-uid')
    @editor_canvas.clear()
    this.draw_layer_bounds layer_uid
    e.stopPropagation()

  delete_layer: (e)->
    if confirm('Delete layer?')
      layer_uid = $(e.target).parent().parent().data('layer-uid')
      @design_canvas.removeLayer(String(layer_uid))      
      @design_canvas.drawLayers()
      @editor_canvas.clear()

  draw_layer_bounds: (uid)->
    bounds = @design.layers.get(uid).get('bounds')
    @editor_canvas.drawBounds bounds, "#ff0000"

  focus_intersection_item: (e)->
    this.collapse_all()
    $(e.target).parent().find('.actions').show()
    
    @editor_canvas.clear()
    this.draw_layer_bounds $(e.target).parent().data('left-uid')
    this.draw_layer_bounds $(e.target).parent().data('right-uid')

  render_no_intersections: ->
    template = $("#no-intersections").html()
    $(this.left_sidebar).html(template)

  render_wrapper: ->
    template = $('#intersections-sidebar').html()
    $(this.left_sidebar).html(template)

  render: ->
    @intersecting_pairs = this.model
    _.templateSettings = {
      interpolate : /\{\{(.+?)\}\}/g
    };

    if @intersecting_pairs.length == 0
      this.render_no_intersections()
    else
      this.render_wrapper()
      list_node = $(this.intersections_list)

      intersecting_pairs_list = @intersecting_pairs.models.reverse()
      for intersecting_pair in intersecting_pairs_list
        left       = intersecting_pair.get('left')
        right      = intersecting_pair.get('right')
        right_name = window.design.layers.get(right).get('name')
        left_name  = window.design.layers.get(left).get('name')
        template_data = 
          left_layer : left_name
          right_layer: right_name
          left_uid   : left
          right_uid  : right
        
        content  = _.template($('#intersection-item').html(), template_data)
        list_node.append($(content))

window.IntersectionView = IntersectionView