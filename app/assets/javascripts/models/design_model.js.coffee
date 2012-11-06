class DesignModel extends Backbone.Model
  urlRoot: "/design"

  initialize: (design_data, sif_data) ->

    @layers = new LayerCollection()
    @layers.reset sif_data['layers']

    @grids = new GridCollection()
    @grids.reset sif_data['grids']

  handleSelection: (type, id) ->
    switch type
      when 'grid'
        this.handleGridSelection(id)
      when 'layer'
        this.handleLayerSelection(id)

  handleGridSelection: (grid_id) ->
    grid = @grids.get(grid_id)
    @editor_iframe.focus_grid_object(grid_id)

  handleLayerSelection: (layer_id) ->
    console.log layer_id

window.DesignModel = DesignModel