class IntersectionView extends Backbone.View
  el: "#app"
  left_sidebar: "#left-sidebar"
  intersections_sidebar: "#intersections-sidebar"
  intersections_list: "#intersections-list"
  
  initialize: ->
    _.templateSettings = {
      interpolate : /\{\{(.+?)\}\}/g
    };

    @design        = window.design
    @editor_area   = window.app.editor_area
    @app           = window.app
    @intersecting_pairs = this.model
    $("#animate-canvas").css("display", "none")
    this.render()


  events:
    "click .top-head-item"     : "focus_intersection_item"
    "click a.remove-panel-btn" : "delete_layer_panel"
    "click a.visibility-panel-btn"   : "visibility_panel"
    "click a.crop-panel-btn"         : "crop_panel"
    "click a.merge-panel-btn"         : "merge_panel"


  collapse_all: ->
    $('.intersection-item .actions').hide()
    $('.intersection-item .action-panel').hide()
    $('.focused-item').removeClass('focused-item')

  clear_selected: ->
    $('.intersection-item a.selected').removeClass('selected')

  clear_canvas: ->
    # Clear layers
    @editor_area.events_canvas.clear()
    @editor_area.animate_canvas.clear()

    @editor_area.events_canvas.draw_layers()
    @editor_area.animate_canvas.draw_layers()

  focus_layer: (layer_id)->
    this.clear_canvas()
    this.draw_layer_bounds layer_id

  delete_involving_intersections: (layer_uid)->
    for intersecting_pair in @intersecting_pairs.models
      if intersecting_pair && (intersecting_pair.get('left') == layer_uid || intersecting_pair.get('right') == layer_uid)
        intersecting_pair.destroy()
        @intersecting_pairs.remove(intersecting_pair)

    $('#intersections-list .intersection-item[data-left-uid="' + layer_uid + '"]').remove()
    $('#intersections-list .intersection-item[data-right-uid="' + layer_uid + '"]').remove()

  get_template_data: (target)->
    container_node = this.get_container(target)
    cid            = container_node.data('cid')

    #Intersection type. Fetch the cid and get the type directly from model
    type           = this.model.getByCid(cid).get('type')

    left_uid:    container_node.data('left-uid')
    right_uid:   container_node.data('right-uid')
    left_layer:  container_node.data('left-name')
    right_layer: container_node.data('right-name')
    type:        type

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
    container   = this.get_container(e.target)
    crop_button = $(container).find('.action-panel .crop-btn')
    intersection_view = this

    $(crop_button).click(this.crop_layer)
    return false

  merge_panel: (e)->
    container = this.get_container(e.target)
    left_id = $(container).data('left-uid')
    right_id = $(container).data('right-uid')

    left_layer = window.design.layers.get(left_id)
    right_layer = window.design.layers.get(right_id)
    if left_layer.get('type') == 'normal' and right_layer.get('type') == 'normal'
      this.fill_show_action_panel(e.target, "#merge-panel")
      merge_btn = $(container).find('.action-panel .merge-btn')
      intersection_view = this
      $(merge_btn).click(this.merge_layer)

    else
      this.fill_show_action_panel(e.target, "#merge-not-possible")

    return false


  visibility_panel: (e)->
    this.fill_show_action_panel(e.target, "#visibility-panel")    
    container         = this.get_container(e.target)
    visibility_nodes  = $(container).find('.action-panel td img.visibility-btn')
    focus_nodes       = $(container).find('.action-panel td.select-layer')
    intersection_view = this

    $(visibility_nodes).click(this.toggle_visibility)
    $(focus_nodes).click((e)->
      layer_id = $(e.target).parent().data('layer-uid')
      intersection_view.focus_layer(layer_id)
    )

    return false    

  delete_layer_panel: (e)->
    this.fill_show_action_panel(e.target, "#delete-panel")

    container    = this.get_container(e.target)
    intersection_view = this

    delete_nodes = $(container).find('.action-panel td img.delete-btn')
    focus_nodes  = $(container).find('.action-panel td.select-layer')

    $(delete_nodes).click(this.delete_layer)
    $(focus_nodes).click((e)->
      layer_id = $(e.target).parent().data('layer-uid')
      intersection_view.focus_layer(layer_id)
    )

    return false

  delete_layer: (e)->
    layer_uid = $(e.target).parent().parent().data('layer-uid')

    intersection_view.focus_layer(layer_uid)
    if confirm('Delete layer?')
      intersection_view.editor_area.design_canvas.canvas_element.removeLayer("l_" + layer_uid)      
      intersection_view.editor_area.design_canvas.canvas_element.drawLayers()
      intersection_view.app.show_notification('Deleting layer')
      intersection_view.delete_layer_sync(layer_uid)
      intersection_view.delete_involving_intersections(layer_uid)
      intersection_view.clear_canvas()

  delete_layer_sync: (uid)->
    url = '/design/' + @design.id + '/delete-layer'
    intersection_view = this
    $.post url, {uid : uid}, ->
      intersection_view.app.hide_notification('Done deleting')

  merge_layer: (e)->
    cid   = $(e.target).parent().parent().parent().data('cid')
    intersection_view.app.show_notification("Merging layers")
    model = intersection_view.model.getByCid(cid)
    post_data = 
      left: model.get('left')
      right: model.get('right')

    url = '/design/' + intersection_view.design.id + '/merge-layer'
    $.post url, post_data, ->
      intersection_view.app.hide_notification("Done merging")
      # Change the layer bounds and remove the intersection itself 

  crop_layer: (e)->
    intersection_view.app.show_notification("Cropping layers")
    cid   = $(e.target).parent().parent().parent().data('cid')
    model = intersection_view.model.getByCid(cid)
    post_data = 
      left: model.get('left')
      right: model.get('right')
      type: model.get('type')

    url = '/design/' + intersection_view.design.id + '/crop-layer'
    $.post url, post_data, (data)->
      if data['data'].hasOwnProperty 'left'
        left_bounds  = data['data']['left']
        intersection_view.design.layers.get(post_data['left']).set('bounds', left_bounds)
      else
        right_bounds = data['data']['right']
        intersection_view.design.layers.get(post_data['right']).set('bounds', right_bounds)
    
      intersection_view.editor_area.events_canvas.clear()
      intersection_view.draw_layer_bounds(post_data['left'])
      intersection_view.draw_layer_bounds(post_data['right'])


      intersection_view.app.hide_notification("Done cropping")
      # Change the layer bounds and remove the intersection itself

  toggle_visibility: (e)->
    layer_uid = $(e.target).parent().parent().data('layer-uid')
    layer     = intersection_view.editor_area.design_canvas.canvas_element.getLayer("l_" + layer_uid)
    if layer.visible == true
      layer.visible = false
    else
      layer.visible = true

    intersection_view.editor_area.design_canvas.draw_layers()

  draw_layer_bounds: (uid)->
    bounds = @design.layers.get(uid).get('bounds')
    @editor_area.events_canvas.draw_bounds bounds, "#ff0000"

  focus_intersection_item: (e)->
    if($(e.target).parent().hasClass('focused-item'))
      this.collapse_all()
      return

    this.collapse_all()
    $(e.target).parent().find('.actions').show("fast")
    $(e.target).parent().addClass('focused-item')
    
    this.clear_canvas()
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
        cid        = intersecting_pair.cid
        right_name = window.design.layers.get(right).get('name')
        left_name  = window.design.layers.get(left).get('name')
        template_data = 
          left_layer : left_name
          right_layer: right_name
          left_uid   : left
          right_uid  : right
          cid        : cid
        
        content  = _.template($('#intersection-item').html(), template_data)
        list_node.append($(content))

window.IntersectionView = IntersectionView