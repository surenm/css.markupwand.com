class DesignModel extends Backbone.Model
  urlRoot: "/design"

  initialize: (design_data, sif_data) ->
    @layers = new LayerCollection()
    @layers.reset sif_data['layers']

  get_assets_root: ->
    return "published/#{this.get('safe_name')}/assets"

  get_layer: (layer_id) ->
    return @layers.get(layer_id)

window.DesignModel = DesignModel