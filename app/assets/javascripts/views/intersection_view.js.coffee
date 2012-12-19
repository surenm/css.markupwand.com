class IntersectionView extends Backbone.View
  el: "#app"
  left_sidebar: "#left-sidebar"
  intersections_sidebar: "#intersections-sidebar"
  intersections_list: "#intersections-list"
  
  initialize: ->
    _.templateSettings = {
      interpolate : /\{\{(.+?)\}\}/g
    };

    @editor_canvas = window.app.editor_canvas
    @design_canvas = @editor_canvas.design_canvas
    @design        = window.design
    @intersecting_pairs = this.model
    $("#animate-canvas").css("display", "none")
    this.render()


  events:
    "click .top-head-item"     : "focus_intersection_item"
    "click a.remove-layer-btn" : "delete_layer_panel"
    "click a.visibility-btn"   : "visibility_panel"
    "click a.crop-btn"         : "crop_panel"
    "click .layer-item"        : "focus_deletable_item"

  collapse_all: ->
    $('.intersection-item .actions').hide()
    $('.intersection-item .action-panel').hide()
    $('.focused-item').removeClass('focused-item')

  clear_selected: ->
    $('.intersection-item a.selected').removeClass('selected')

  focus_deletable_item: (e)->
    layer_uid = $(e.target).parent().data('layer-uid')
    @editor_canvas.clear()
    this.draw_layer_bounds layer_uid
    e.stopPropagation()

  delete_involving_intersections: (layer_uid)->
    for intersecting_pair in @intersecting_pairs.models
      if intersecting_pair && (intersecting_pair.get('left') == layer_uid || intersecting_pair.get('right') == layer_uid)
        intersecting_pair.destroy()
        @intersecting_pairs.remove(intersecting_pair)

    $('#intersections-list .intersection-item[data-left-uid="' + layer_uid + '"]').remove()
    $('#intersections-list .intersection-item[data-right-uid="' + layer_uid + '"]').remove()

  get_template_data: (target)->
    container_node = this.get_container(target) 

    left_uid:    container_node.data('left-uid')
    right_uid:   container_node.data('right-uid')
    left_layer:  container_node.data('left-name')
    right_layer: container_node.data('right-name')

  get_link_node: (target)->
    if target.nodeName.toLowerCase() == "a"
      return target
    else
      return $(target).parent()

  get_container: (target)->
    link_node = this.get_link_node(target)
    $(link_node).parent().parent()

  fill_show_action_panel: (target, panel)->
    this.clear_selected()
    content   = _.template($(panel).html(), this.get_template_data(target))
    container = this.get_container(target)
    link      = this.get_link_node(target)
    $(container).find('.action-panel').html(content)
    $(container).find('.action-panel').show()
    $(link).addClass('selected')


  crop_panel: (e)->
    this.fill_show_action_panel(e.target, "#crop-panel")
    return false

  visibility_panel: (e)->
    this.fill_show_action_panel(e.target, "#visibility-panel")
    return false    

  delete_layer_panel: (e)->
    this.fill_show_action_panel(e.target, "#delete-panel")

    container    = this.get_container(e.target)
    delete_nodes = $(container).find('.action-panel td img')
    intersection_view = this
    $(delete_nodes).click(this.delete_layer) 
    return false

  delete_layer: (e)->
    if confirm('Delete layer?')
      layer_uid = $(e.target).parent().parent().data('layer-uid')
      window.app.editor_canvas.design_canvas.removeLayer("l_" + layer_uid)      
      window.app.editor_canvas.design_canvas.drawLayers()
      window.app.editor_canvas.clear()
      intersection_view.delete_layer_sync(layer_uid)
      intersection_view.delete_involving_intersections(layer_uid)

  delete_layer_sync: (uid)->
    url = '/design/' + @design.id + '/delete-layer'
    $.post url, {uid : uid}, ->
      console.log("Posted") 

  draw_layer_bounds: (uid)->
    bounds = @design.layers.get(uid).get('bounds')
    @editor_canvas.drawBounds bounds, "#ff0000"

  focus_intersection_item: (e)->
    if($(e.target).parent().hasClass('focused-item'))
      this.collapse_all()
      return

    this.collapse_all()
    $(e.target).parent().find('.actions').show("fast")
    $(e.target).parent().addClass('focused-item')
    
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