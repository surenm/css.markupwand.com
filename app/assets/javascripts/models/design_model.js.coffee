class DesignModel extends Backbone.Model
  urlRoot: "/design"

  initialize: (design_data, sif_data) ->
    @layers = new LayerCollection()
    @layers.reset sif_data['layers']

    @grouping_boxes = new GroupingBoxCollection()
    @grouping_boxes.reset sif_data['grouping_boxes']

  get_assets_root: ->
    return "published/#{this.get('safe_name')}/assets"

  get_layer: (layer_id) ->
    return @layers.get(layer_id)

  get_grouping_box: (grouping_box_id) ->
    return @grouping_boxes.get(grouping_box_id)

window.DesignModel = DesignModel