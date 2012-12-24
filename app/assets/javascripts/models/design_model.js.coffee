class DesignModel extends Backbone.Model
  urlRoot: "/design"

  initialize: (design_data) ->
    @layers = new LayerCollection()
    @grouping_boxes = new GroupingBoxCollection()

    # Reset collections
    this.reset_collection_data()
  reset_collection_data: () ->
    sif_data = this.get('sif')
    @layers.reset sif_data['layers']
    @grouping_boxes.reset sif_data['grouping_boxes']

  get_bounds: () ->
    bounds = 
      top: 0
      left: 0
      bottom: this.get('height') 
      right: this.get('width')

  get_assets_root: ->
    return "published/#{this.get('safe_name')}/assets"

  get_layer: (layer_id) ->
    return @layers.get(layer_id)

  get_grouping_box: (grouping_box_id) ->
    return @grouping_boxes.get(grouping_box_id)

window.DesignModel = DesignModel