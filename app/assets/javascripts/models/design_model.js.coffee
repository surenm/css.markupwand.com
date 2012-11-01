class DesignModel extends Backbone.Model
  urlRoot: "/design"

  initialize: (design_data, sif_data) ->

    @layers = new LayerCollection()
    @layers.reset sif_data['layers']

    @grids = new GridCollection()
    @grids.reset sif_data['grids']


window.DesignModel = DesignModel